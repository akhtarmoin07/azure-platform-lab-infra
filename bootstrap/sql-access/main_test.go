package main

import "testing"

func TestValidatePrincipal(t *testing.T) {
	tests := []struct {
		name      string
		principal externalPrincipal
		wantError bool
	}{
		{name: "external group", principal: externalPrincipal{Name: "developers", ObjectID: "00000000-0000-0000-0000-000000000001", Type: "X", Role: "application_developer"}},
		{name: "managed identity", principal: externalPrincipal{Name: "backend", ObjectID: "00000000-0000-0000-0000-000000000002", Type: "E", Role: "application_runtime"}},
		{name: "unsupported type", principal: externalPrincipal{Name: "bad", ObjectID: "00000000-0000-0000-0000-000000000003", Type: "S", Role: "application_runtime"}, wantError: true},
		{name: "missing ID", principal: externalPrincipal{Name: "bad", Type: "E", Role: "application_runtime"}, wantError: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := validatePrincipal(test.principal)
			if (err != nil) != test.wantError {
				t.Fatalf("validatePrincipal() error = %v, wantError %v", err, test.wantError)
			}
		})
	}
}
