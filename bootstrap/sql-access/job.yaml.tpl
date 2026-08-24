apiVersion: v1
kind: ServiceAccount
metadata:
  name: sql-access-bootstrap
  namespace: platform-system
  annotations:
    azure.workload.identity/client-id: "${SQL_BOOTSTRAP_CLIENT_ID}"
automountServiceAccountToken: false
---
apiVersion: batch/v1
kind: Job
metadata:
  name: sql-access-bootstrap
  namespace: platform-system
  labels:
    app.kubernetes.io/name: sql-access-bootstrap
spec:
  backoffLimit: 1
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: sql-access-bootstrap
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: sql-access-bootstrap
      restartPolicy: Never
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: bootstrap
          image: "${BOOTSTRAP_IMAGE}"
          imagePullPolicy: Always
          env:
            - { name: SQL_SERVER, value: "${SQL_SERVER}" }
            - { name: DEV_DATABASE, value: "pharmacy-dev" }
            - { name: PROD_DATABASE, value: "pharmacy-prod" }
            - { name: PLATFORM_ADMIN_GROUP_NAME, value: "${PLATFORM_ADMIN_GROUP_NAME}" }
            - { name: PLATFORM_ADMIN_GROUP_ID, value: "${PLATFORM_ADMIN_GROUP_ID}" }
            - { name: DEV_DEVELOPER_GROUP_NAME, value: "${DEV_DEVELOPER_GROUP_NAME}" }
            - { name: DEV_DEVELOPER_GROUP_ID, value: "${DEV_DEVELOPER_GROUP_ID}" }
            - { name: PROD_READER_GROUP_NAME, value: "${PROD_READER_GROUP_NAME}" }
            - { name: PROD_READER_GROUP_ID, value: "${PROD_READER_GROUP_ID}" }
            - { name: PROD_ADMIN_GROUP_NAME, value: "${PROD_ADMIN_GROUP_NAME}" }
            - { name: PROD_ADMIN_GROUP_ID, value: "${PROD_ADMIN_GROUP_ID}" }
            - { name: DEV_BACKEND_IDENTITY_NAME, value: "id-azplab-backend-dev" }
            - { name: DEV_BACKEND_IDENTITY_ID, value: "${DEV_BACKEND_CLIENT_ID}" }
            - { name: PROD_BACKEND_IDENTITY_NAME, value: "id-azplab-backend-prod" }
            - { name: PROD_BACKEND_IDENTITY_ID, value: "${PROD_BACKEND_CLIENT_ID}" }
            - { name: DEV_MIGRATION_IDENTITY_NAME, value: "id-azplab-migration-dev" }
            - { name: DEV_MIGRATION_IDENTITY_ID, value: "${DEV_MIGRATION_CLIENT_ID}" }
            - { name: PROD_MIGRATION_IDENTITY_NAME, value: "id-azplab-migration-prod" }
            - { name: PROD_MIGRATION_IDENTITY_ID, value: "${PROD_MIGRATION_CLIENT_ID}" }
          resources:
            requests: { cpu: 50m, memory: 64Mi }
            limits: { cpu: 200m, memory: 128Mi }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
