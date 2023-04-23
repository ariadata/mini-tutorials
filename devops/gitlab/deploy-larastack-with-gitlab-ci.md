# Steps to Create Laravel Stack + CI/CD (single branch = main )

### 01- Create new repository in **GitLab**
### 02- Create a new `Access Token` for the repository:
> `Settings` -> `Access Tokens` -> `Add a project access token`
- Name: `ssh-connect-ci-cd`
- Expiration date: `Never`
- Roles: `Reporter`
- Scopes: `read_api`, `read_repository`, `read_registry`
- Click `Create personal access token`
- Copy the `Access Token` and `repo_url` for later use (in step 08 and 11)

### 03- Create VM and Assign internal IP (+ vlan IP)

### 04- Run the following commands inside VM:
```bash
# change hostname
hostnamectl set-hostname laravel-stack
hwclock --hctosys
apt update && apt upgrade && apt --yes install curl ntp rsync sudo && apt autoremove -y
systemctl enable --now ntp && systemctl restart ntp
dpkg-reconfigure tzdata
```

### 05- Enable Public Key Authentication in `/etc/ssh/sshd_config`:
```bash
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd
```

### 06- Create User and make access to `sudo`:
```bash
adduser production
usermod -aG sudo production
su - production
```

### 07- Run the following commands to create `ssh` keys, and copy the output of `cat ~/.ssh/id_rsa` to use in `GitLab` later:
```bash
ssh-keygen -t rsa -b 2048 -C "ssh-connect-ci-cd"
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
cat ~/.ssh/id_rsa
# Copy and Save the output to use in GitLab
```

### 08- Run these commands :
* Replace `ACCESS_TOKEN` with the `Access Token` you created in `GitLab` (Step 02)
* Change gitlab url to your gitlab url
```bash
echo "[credential]
	helper = store
" > ~/.gitconfig

echo "https://oauth2:ACCESS_TOKEN@git.arzinja.dev" > ~/.git-credentials

git config --global credential.helper store
```

### 09- Run the following commands to install `docker` and `docker-compose`:
```bash
bash <(curl -sSL https://github.com/ariadata/dockerhost-sh/raw/main/dockerhost-basic-debian-11-non-root.sh)
```

### 10- Run fresh [Larastack-V2](https://github.com/ariadata/dc-larastack-v2) in your `Local` machine. (configure ports and .env variables)

### 11- in your `larastack` folder of your `Local` machine, run the following commands:
```bash
rm -rf .git src/.git
cd src/
git config --global user.name "Mehrdad Amini"
git config user.email "mehrdad@arzinja.dev"
git config --global credential.helper store

git init && git switch -c main
git remote add origin https://your-gitlab-url/your-gitlab-repo.git
git add .
git commit -m "Initial Commit"
git push -u origin main

```

### 12- In **gitlab** , goto `Settings` -> `CI/CD` -> `Variables` and add the following variables
as `variable` and `not masked`
> `MAIN_IP_ADDRESS` : Internal IP of VM

> `MAIN_SSH_PORT` : `22`

> `MAIN_SSH_USER` : `production`

> `MAIN_PRIVATE_KEY` : Private Key of VM (from step 07)

### 13- Goto `CI/CD` -> `Editor` and click `Configure pipeline`, Use the following code, modiify as needed:
```yaml
stages:
  - deploy-main-to-production
deploy-main-to-production:
  stage: deploy-main-to-production
  image: ariadata/ssh-client-alpine:openssh-client
  before_script:
    - eval $(ssh-agent -s)
    - echo "$MAIN_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan -p $MAIN_SSH_PORT $MAIN_IP_ADDRESS >> ~/.ssh/known_hosts
    - chmod 644 ~/.ssh/known_hosts
  only:
    - main
  script:
    - ssh -o StrictHostKeyChecking=no $MAIN_SSH_USER@$MAIN_IP_ADDRESS -p $MAIN_SSH_PORT "cd /home/production/dc-larastack && bash update-project.sh main"

```
commit the changes


### 14- login to VM do these steps:
```bash
mkdir -p /home/production/dc-larastack
cd /home/production/dc-larastack
mkdir -p ./data/{mongo,mysql,pgsql,redis}
git clone -b main https://your-gitlab-url/your-gitlab-repo.git src
```
### 15- Copy these files/folders from your local machine to VM (in this directory):
- `configs` -> `/home/production/dc-larastack/configs`
- `logs`	-> `/home/production/dc-larastack/logs`
- `.env`	-> `/home/production/dc-larastack/.env`
- `src/.env`	-> `/home/production/dc-larastack/src/.env`
- `docker-compose.yml`	-> `/home/production/dc-larastack/docker-compose.yml`

### 16- Create `/home/production/dc-larastack/update-project.sh` and copy the following code in it:
```bash
#!/bin/bash
cd "$(dirname "$0")"
docker-compose exec -u webuser -T supervisor supervisorctl stop laravel-schedule laravel-short-schedule laravel-horizon
docker-compose exec -u webuser -T workspace php artisan down
docker-compose exec -u webuser -T workspace php artisan route:clear
docker-compose exec -u webuser -T workspace php artisan config:clear
cd ./src/
git reset --hard
git clean -f -d
git pull
git checkout $1
# git checkout main
cd ../

docker-compose exec -u webuser -T workspace composer update --no-dev --no-interaction
# docker-compose exec -u webuser -T workspace composer install --no-dev --no-interaction
docker-compose exec -u webuser -T workspace npm install
docker-compose exec -u webuser -T workspace npm run build
# docker-compose exec php composer update -q --no-ansi --no-interaction --no-scripts --no-progress --prefer-dist

# php artisan migrate
docker-compose exec -u webuser -T workspace php artisan migrate --force
docker-compose exec -u webuser -T workspace php artisan db:seed --force
docker-compose exec -u webuser -T workspace php artisan module:seed --force

# cache functions
docker-compose exec -u webuser -T workspace php artisan config:cache
docker-compose exec -u webuser -T workspace php artisan route:cache

# todo : Other laravel cache here
# ###

docker-compose exec -u webuser -T supervisor supervisorctl start laravel-schedule laravel-short-schedule laravel-horizon
docker-compose exec -u webuser -T workspace php artisan up

```

### 17- (**Important**) Edit `.env`, `src/.env` and change ports and database vars

### 17- run these commands in VM:
```bash
cd /home/production/dc-larastack
docker-compose pull
docker-compose up -d

docker-compose exec -u webuser workspace composer update
docker-compose exec -u webuser workspace php artisan key:generate --force
docker-compose exec -u webuser workspace php artisan migrate:fresh --force
docker-compose exec -u webuser workspace php artisan db:seed --force
docker-compose exec -u webuser workspace php artisan storage:link
# docker-compose exec -u webuser workspace php artisan route:cache
# docker-compose exec -u webuser workspace php artisan config:cache
# docker-compose exec -u webuser workspace php artisan view:cache
# docker-compose exec -u webuser workspace php artisan optimize
# docker-compose exec -u webuser workspace php artisan queue:restart
# docker-compose exec -u webuser workspace php artisan queue:work --daemon

bash update-project.sh main

```

### 18- In `GitLab` , goto `CI/CD` -> `Pipelines` and click `Run Pipeline` to test the pipeline

## todo:
- make branches protected
- make ci of stage first then ci of product
- make




