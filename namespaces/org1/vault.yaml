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
