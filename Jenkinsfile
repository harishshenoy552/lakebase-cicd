// Jenkinsfile — one pipeline where developers and DBAs collaborate.
//
// PR builds:   create an ephemeral Lakebase branch -> migrate -> test -> (teardown in post)
// main builds: DBA-gated approval -> promote the same migration to production
//
// The pipeline is a thin orchestrator around scripts/*.sh, so the exact same
// commands run on a laptop and in CI. Auth is a Databricks CLI profile backed
// by a service principal (configure it on the agent, or via withCredentials).

pipeline {
  agent any

  environment {
    PROJECT            = 'projects/orders-api'
    DATABRICKS_PROFILE = 'jenkins-sp'
    DB_NAME            = 'orders'
    BRANCH_ID          = "ci-pr-${env.CHANGE_ID}"   // Jenkins sets CHANGE_ID on PR builds
    MIGRATION_TOOL     = 'sql'                        // set to 'liquibase' to use the changelog
  }

  options {
    timestamps()
    ansiColor('xterm')
  }

  stages {
    stage('Create DB branch') {
      when { changeRequest() }
      steps { sh './scripts/create_branch.sh' }
    }

    stage('Migrate') {
      when { changeRequest() }
      steps { sh './scripts/migrate.sh' }
    }

    stage('Test') {
      when { changeRequest() }
      // test.sh runs the pytest suite, or falls back to psql-only SQL assertions
      // when Python deps can't be installed (offline/locked-down agents).
      steps { sh './scripts/test.sh' }
    }

    stage('DBA approval') {
      when { branch 'main' }
      steps {
        // The DBA approves the exact migration that already passed CI against
        // production-shaped data — not SQL reviewed in the abstract.
        input message: "Promote ${env.PROJECT} migrations to production?",
              submitter: 'dba-team'
      }
    }

    stage('Promote to production') {
      when { branch 'main' }
      steps { sh './scripts/promote.sh' }
    }
  }

  post {
    always {
      // Reclaim the ephemeral branch whether the build passed or failed.
      script {
        if (env.CHANGE_ID) {
          sh './scripts/teardown.sh || true'
        }
      }
    }
  }
}
