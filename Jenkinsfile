pipeline {
  agent any
  options {
    timestamps()
    disableConcurrentBuilds()
  }
  parameters {
    choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'apply = deploy, destroy = tear down')
  }
  environment {
    AWS_DEFAULT_REGION    = 'us-east-1'
    AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
    AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    GEMINI_API_KEY        = credentials('gemini-api-key')
    TF_STATE_BUCKET       = credentials('tf-state-bucket')
    TF_IN_AUTOMATION      = 'true'
    ACTION                = "${params.ACTION ?: 'apply'}"
  }
  stages {
    stage('Secrets scan') {
      steps {
        sh 'mkdir -p reports'
        sh 'gitleaks detect --no-git --source . --redact --exit-code 1'
      }
    }
    stage('IaC security scan') {
      steps {
        sh 'checkov -d terraform --framework terraform --quiet --compact --soft-fail'
        sh 'checkov -d terraform --framework terraform --soft-fail -o json > reports/checkov.json || true'
      }
    }
    stage('Init and validate') {
      steps {
        dir('terraform') {
          sh '''
            terraform init -input=false -backend-config="bucket=$TF_STATE_BUCKET"
            terraform fmt -check -recursive
            terraform validate
          '''
        }
      }
    }
    stage('Plan') {
      steps {
        dir('terraform') {
          sh '''
            if [ "$ACTION" = "destroy" ]; then FLAG="-destroy"; else FLAG=""; fi
            terraform plan -input=false -no-color $FLAG -out=tfplan
            terraform show -no-color tfplan > ../reports/plan.txt
          '''
        }
      }
    }
    stage('AI review') {
      steps {
        sh 'python3 scripts/ai_review.py reports/checkov.json reports/plan.txt reports/ai_review.md'
        sh 'cat reports/ai_review.md'
      }
    }
    stage('Approval') {
      steps {
        input message: "Review the plan and the AI review above. Run '${env.ACTION}'?", ok: 'Proceed'
      }
    }
    stage('Apply') {
      steps {
        dir('terraform') {
          sh 'terraform apply -input=false -no-color tfplan'
        }
      }
    }
    stage('Smoke test') {
      when { expression { env.ACTION == 'apply' } }
      steps {
        dir('terraform') {
          sh '''
            terraform output -no-color | tee ../reports/outputs.txt
            IP=$(terraform output -raw web_public_ip)
            for i in $(seq 1 30); do
              if curl -fsS --max-time 5 "http://$IP" | grep -q "Defense in Depth"; then
                echo "Smoke test passed"
                exit 0
              fi
              sleep 10
            done
            echo "Smoke test FAILED"
            exit 1
          '''
        }
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
    }
  }
}