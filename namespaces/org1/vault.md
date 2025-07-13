jobs:
  detect-namespaces:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.detect.outputs.matrix }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Fetch main
        run: git fetch origin main

      - name: Detect changed namespaces
        id: detect
        run: |
          changed_files=$(git diff --name-only origin/main...HEAD)
          namespaces=()

          while IFS= read -r file; do
            if [[ "$file" =~ ^namespaces/([^/]+)/(dev|prod)\.tfvars$ ]]; then
              namespace="${BASH_REMATCH[1]}"
              echo "Found changed tfvars file: $file (namespace: $namespace)"
              namespaces+=("$namespace")
            fi
          done <<< "$changed_files"

          if [ ${#namespaces[@]} -gt 0 ]; then
            unique_namespaces=($(printf '%s\n' "${namespaces[@]}" | sort -u))
            json_array="["; for i in "${!unique_namespaces[@]}"; do
              [ $i -gt 0 ] && json_array+=","
              json_array+="\"${unique_namespaces[i]}\""
            done
            json_array+="]"
            echo "Changed namespaces: ${unique_namespaces[*]}"
            echo "matrix=$json_array" >> $GITHUB_OUTPUT
          else
            echo "matrix=[]" >> $GITHUB_OUTPUT
            echo "No namespace changes detected"
          fi

  terraform:
    needs: detect-namespaces
    if: needs.detect-namespaces.outputs.matrix != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        namespace: ${{ fromJson(needs.detect-namespaces.outputs.matrix) }}
    env:
      AWS_DEFAULT_REGION: us-east-1

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.7.1

      - name: Set ENV based on file change
        id: env-detect
        run: |
          changed_files=$(git diff --name-only origin/main...HEAD)
          if echo "$changed_files" | grep -q "namespaces/${{ matrix.namespace }}/prod.tfvars"; then
            echo "env=prod" >> $GITHUB_OUTPUT
            echo "tfvars=prod.tfvars" >> $GITHUB_ENV
            echo "backend=backend-prod.hcl" >> $GITHUB_ENV
          else
            echo "env=dev" >> $GITHUB_OUTPUT
            echo "tfvars=dev.tfvars" >> $GITHUB_ENV
            echo "backend=backend-dev.hcl" >> $GITHUB_ENV
          fi

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_DEFAULT_REGION }}

      - name: Terraform Init
        run: |
          cd namespaces/${{ matrix.namespace }}
          echo "Namespace: ${{ matrix.namespace }}, Environment: ${{ steps.env-detect.outputs.env }}"
          terraform init --backend-config=${{ env.backend }} --reconfigure

      - name: Terraform Plan
        run: |
          cd namespaces/${{ matrix.namespace }}
          terraform plan --var-file=${{ env.tfvars }}

      - name: Terraform Apply
        run: |
          cd namespaces/${{ matrix.namespace }}
          terraform apply -auto-approve --var-file=${{ env.tfvars }}




- name: Find changed namespace dirs
  id: find_dirs
  shell: bash
  run: |
    git fetch origin main

    # Only look for changed .tfvars files under namespaces/
    changed_files=$(git diff --name-only origin/main...HEAD | grep '^namespaces/.*/.*\.tfvars$' || true)

    if [[ -z "$changed_files" ]]; then
      echo "No tfvars file changes detected."
      echo "dirs=[]" >> $GITHUB_OUTPUT
      exit 0
    fi

    # Extract unique namespace names
    changed_dirs=$(echo "$changed_files" | cut -d/ -f2 | sort -u | jq -R . | jq -s -c .)

    echo "Changed namespace directories: $changed_dirs"
    echo "dirs=$changed_dirs" >> $GITHUB_OUTPUT
