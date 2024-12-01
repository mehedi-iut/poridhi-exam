# To-Do app in AWS using EC2 and ALB

## Create Infra in AWS
To create Infra in AWS, we will run the terraform script to create the necessary resources
1. Install AWS cli
2. install terraform
3. run `aws configure` to login using accesskey and accessSecretKey
4. Navigate to `infra` and run below command
```bash
terraform init
terraform plan
terraform apply -auto-approve
```

After the successful run, it will show ALB address and two ec2 public ip. and also create a `docker-key.pem` which can be used to login to ec2

## Copy the source code to ec2 instances
we need to copy the source code to ec2 intances and run the docker compose to run our to-do application
1. use `scp` to copy the `todo-app` folder to ec2 instances
```sh
scp -r -i ./docker-key.pem ../todo-app/ ubuntu@<public-ip>:/home/ubuntu
```

2. ssh into the ec2 instances
```sh
ssh -i docker-key.pem ubuntu@<public-ip>
```

3. update the `.env` file inside `todo-app` folder and replace the `localhost` to ALB address
```sh
# Frontend Configuration
FRONTEND_PORT=3000
FRONTEND_HOST=<alb-address>

# Backend Configuration
BACKEND_PORT=8080
BACKEND_HOST=<alb-address>

# Nginx Configuration
NGINX_PORT=80
```

4. navigate to `todo-app` folder in ec2
```sh
cd todo-app
docker compose up --build
```

Now, we can hit the alb address to get our application