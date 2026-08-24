package main

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"net/url"
	"os"
	"time"

	_ "github.com/microsoft/go-mssqldb/azuread"
)

type externalPrincipal struct {
	Name     string
	ObjectID string
	Type     string
	Role     string
}

type databaseAccess struct {
	Database   string
	Principals []externalPrincipal
}

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	server := requiredEnvironment("SQL_SERVER")

	common := []externalPrincipal{
		principalFromEnvironment("PLATFORM_ADMIN_GROUP", "X", "platform_administrator"),
	}
	configurations := []databaseAccess{
		{
			Database: requiredEnvironment("DEV_DATABASE"),
			Principals: append(common,
				principalFromEnvironment("DEV_DEVELOPER_GROUP", "X", "application_developer"),
				principalFromEnvironment("DEV_BACKEND_IDENTITY", "E", "application_runtime"),
				principalFromEnvironment("DEV_MIGRATION_IDENTITY", "E", "schema_migrator"),
			),
		},
		{
			Database: requiredEnvironment("PROD_DATABASE"),
			Principals: append(common,
				principalFromEnvironment("PROD_READER_GROUP", "X", "application_reader"),
				principalFromEnvironment("PROD_ADMIN_GROUP", "X", "database_administrator"),
				principalFromEnvironment("PROD_BACKEND_IDENTITY", "E", "application_runtime"),
				principalFromEnvironment("PROD_MIGRATION_IDENTITY", "E", "schema_migrator"),
			),
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	for _, configuration := range configurations {
		if err := reconcileDatabase(ctx, server, configuration); err != nil {
			logger.Error("reconcile database access", "database", configuration.Database, "error", err)
			os.Exit(1)
		}
		logger.Info("database access reconciled", "database", configuration.Database)
	}
}

func principalFromEnvironment(prefix, principalType, role string) externalPrincipal {
	return externalPrincipal{
		Name:     requiredEnvironment(prefix + "_NAME"),
		ObjectID: requiredEnvironment(prefix + "_ID"),
		Type:     principalType,
		Role:     role,
	}
}

func requiredEnvironment(name string) string {
	value := os.Getenv(name)
	if value == "" {
		fmt.Fprintf(os.Stderr, "%s is required\n", name)
		os.Exit(2)
	}
	return value
}

func reconcileDatabase(ctx context.Context, server string, configuration databaseAccess) error {
	connectionURL := &url.URL{Scheme: "sqlserver", Host: server}
	query := connectionURL.Query()
	query.Set("database", configuration.Database)
	query.Set("fedauth", "ActiveDirectoryWorkloadIdentity")
	query.Set("encrypt", "true")
	query.Set("TrustServerCertificate", "false")
	connectionURL.RawQuery = query.Encode()

	database, err := sql.Open("azuresql", connectionURL.String())
	if err != nil {
		return fmt.Errorf("open connection: %w", err)
	}
	defer database.Close()
	if err := database.PingContext(ctx); err != nil {
		return fmt.Errorf("authenticate to %s: %w", configuration.Database, err)
	}

	transaction, err := database.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer transaction.Rollback()

	if _, err := transaction.ExecContext(ctx, roleDDL); err != nil {
		return fmt.Errorf("reconcile roles: %w", err)
	}
	for _, principal := range configuration.Principals {
		if err := validatePrincipal(principal); err != nil {
			return err
		}
		if _, err := transaction.ExecContext(ctx, principalDDL,
			sql.Named("principal_name", principal.Name),
			sql.Named("object_id", principal.ObjectID),
			sql.Named("principal_type", principal.Type),
		); err != nil {
			return fmt.Errorf("reconcile principal %q: %w", principal.Name, err)
		}
		if _, err := transaction.ExecContext(ctx, roleMembershipDDL,
			sql.Named("principal_name", principal.Name),
			sql.Named("role_name", principal.Role),
		); err != nil {
			return fmt.Errorf("assign %q to %q: %w", principal.Name, principal.Role, err)
		}
	}
	if err := transaction.Commit(); err != nil {
		return fmt.Errorf("commit access changes: %w", err)
	}
	return nil
}

func validatePrincipal(principal externalPrincipal) error {
	if principal.Name == "" || principal.ObjectID == "" || principal.Role == "" {
		return fmt.Errorf("principal name, object ID and role must not be empty")
	}
	if principal.Type != "E" && principal.Type != "X" {
		return fmt.Errorf("principal %q has unsupported type %q", principal.Name, principal.Type)
	}
	return nil
}

const roleDDL = `
IF DATABASE_PRINCIPAL_ID(N'application_reader') IS NULL CREATE ROLE [application_reader];
IF DATABASE_PRINCIPAL_ID(N'application_runtime') IS NULL CREATE ROLE [application_runtime];
IF DATABASE_PRINCIPAL_ID(N'application_developer') IS NULL CREATE ROLE [application_developer];
IF DATABASE_PRINCIPAL_ID(N'schema_migrator') IS NULL CREATE ROLE [schema_migrator];
IF DATABASE_PRINCIPAL_ID(N'database_administrator') IS NULL CREATE ROLE [database_administrator];
IF DATABASE_PRINCIPAL_ID(N'platform_administrator') IS NULL CREATE ROLE [platform_administrator];

GRANT SELECT ON SCHEMA::dbo TO [application_reader];
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO [application_runtime];
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::dbo TO [application_developer];
GRANT CREATE TABLE, CREATE VIEW, CREATE PROCEDURE, CREATE FUNCTION TO [schema_migrator];
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE, ALTER, CONTROL, REFERENCES ON SCHEMA::dbo TO [schema_migrator];
GRANT CONTROL DATABASE TO [database_administrator];
GRANT CONTROL DATABASE TO [platform_administrator];
`

const principalDDL = `
DECLARE @name SYSNAME = @principal_name;
DECLARE @id UNIQUEIDENTIFIER = CONVERT(UNIQUEIDENTIFIER, @object_id);
DECLARE @type CHAR(1) = @principal_type;
DECLARE @expected_sid VARBINARY(16) = CONVERT(VARBINARY(16), @id);
DECLARE @actual_sid VARBINARY(85) = (SELECT sid FROM sys.database_principals WHERE name = @name);

IF @actual_sid IS NULL
BEGIN
    DECLARE @create_sql NVARCHAR(MAX) = N'CREATE USER ' + QUOTENAME(@name)
        + N' WITH SID = ' + CONVERT(VARCHAR(MAX), @expected_sid, 1)
        + N', TYPE = ' + @type + N';';
    EXEC sp_executesql @create_sql;
END
ELSE IF @actual_sid <> @expected_sid
BEGIN
    THROW 50001, 'Existing database principal has a different Microsoft Entra object ID.', 1;
END;
`

const roleMembershipDDL = `
DECLARE @member SYSNAME = @principal_name;
DECLARE @role SYSNAME = @role_name;
IF NOT EXISTS (
    SELECT 1
    FROM sys.database_role_members drm
    JOIN sys.database_principals roles ON roles.principal_id = drm.role_principal_id
    JOIN sys.database_principals members ON members.principal_id = drm.member_principal_id
    WHERE roles.name = @role AND members.name = @member
)
BEGIN
    DECLARE @membership_sql NVARCHAR(MAX) = N'ALTER ROLE ' + QUOTENAME(@role)
        + N' ADD MEMBER ' + QUOTENAME(@member) + N';';
    EXEC sp_executesql @membership_sql;
END;
`
