Assume that we have a CI/CD pipeline that deploys our application to a remote server. We need to connect to the remote server to run some commands.

1- Create a new `Access Token` in **GitLab**
> `Settings` -> `Access Tokens` -> `Add a project access token`

- Name: `ssh-connect-ci-cd`
- Expiration date: `Never`
- Scopes: `read_api`, `read_repository`, `read_registry`
- Click `Create personal access token`

2- In **Remote Server**  generate a new SSH Key pair (if you don't have one)
```
ssh-keygen -t rsa -b 4096 -C "ssh-connect-ci-cd"
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa
# Copy the output

```
3- In **Remote Server** config access to GitLab

> enable `publicKeyAuthentication` in `/etc/ssh/sshd_config` and restart sshd service

```bash
echo "[credential]
	helper = store
" > ~/.gitconfig

# change with your own values
# change ACCESS_TOKEN_HERE with the token generated in step 1
# change git.example.com with your own GitLab server
echo "https://oauth2:ACCESS_TOKEN_HERE@git.example.com" > ~/.git-credentials

git config --global credential.helper store

```


4- In **GitLab** add the Private key into CI/CD variables
> `Settings` -> `CI/CD` -> `Variables` -> `Add variable`

5- Now in **Gitlab Server** we can use like this in our CI/CD pipeline in `.gitlab-ci.yml` file
```yaml
deploy-to-server:
  stage: deploy-to-server
  image: ariadata/ssh-client-alpine:openssh-client
  before_script:
    - eval $(ssh-agent -s)
    - echo "$STAGE_SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan -p $STAGE_SSH_PORT $STAGE_SSH_ADDRESS >> ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
  only:
    - develop
  script:
    - ssh -o StrictHostKeyChecking=no $STAGE_SSH_USER@$STAGE_SSH_ADDRESS -p $STAGE_SSH_PORT "git clone your_private_repo.git"

```