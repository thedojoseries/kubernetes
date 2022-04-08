# Introduction

This folder contains all the scripts to launch the infrastructure for you to run your own Dojo event. **Please note the following:**

* This repository does its best at letting you know what resources will be launched. **Ultimately, it's your responsibility to pay any bills that running this challenge might incur.**
* These scripts have been tested on macOS Monterey (version 12.1) using ZSH. Feel free to change the scripts and adapt them to Linux or Windows (create a folder for each OS or Linux Distro). Please submit a PR to collaborate to this repository.
* These scripts are by no means as fully tested as the challenge is. There might be a lot of room for improvement. Again, PRs are welcome :)
* This repository is not actively maintained. I will do my best to reply and look at issues and PRs

# Resources launched by the script

Once you run the scripts, the following AWS resources will be launched:

* IAM Users
* IAM Access Keys
* IAM Policies
* IAM Login Profile for each user
* VPC
* Internet Gateway
* Subnets
* Route Tables
* Routes
* KMS keys and aliases
* EKS cluster
* EKS Node Groups
* ECR Repositories
* Cloud9 Environments

Make sure to use the [AWS Calculator](https://calculator.aws/#/) to know how much launching this infrastructure will cost you. Again, you are the sole responsible for paying your AWS bill, I'm sure you understand that :)

# Prerequisites

Before you run the `deploy-infra.sh` script, make sure to:

* Install [Terraform v1.0+](https://www.terraform.io/downloads)
* Install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* Create a [Keybase](https://keybase.io/) user if you haven't got one yet and install the [Keybase app](https://keybase.io/docs/the_app/install_macos)

When you run the `deploy-infra.sh` script, the script will ask you for the following:

* `Enter minimum team number` - for this challenge, teams are numbered. If you will have 10 teams and would like to number them 1 to 10 (i.e., team1, team2, team3, team4, etc), enter `1` here.
* `Enter maximum team number` - this is the number assigned to the last team. If you want to number teams 1 to 10, enter `10` here
* `Enter the number of nodes for the cluster` - this is the number of EC2 instances to be used in your cluster. This does not take into account the [Control Plane](https://kubernetes.io/docs/concepts/overview/components/) (that's taken care by EKS). You are charged separately for the [Control Plane](https://aws.amazon.com/eks/pricing/)
* `Enter the instance type for the nodes` - the EC2 instance type (t2.micro, t3.medium etc) for your Kubernetes nodes. **[Beware that each instance type can only handle a certain number of Pods](https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt)**. If you run out of capacity, you will need to either increase the number of nodes or use a bigger and more powerful instance type
* `Enter name of the AWS profile configured in your machine` - the name of the profile you used to configure your AWS CLI (i.e., when you ran `aws configure --profile <PROFILE_NAME>`)

Finally, you will notice that there's a file called `aws-auth-patch.yaml`. [This file basically gives permission to the IAM Users created by Terraform to access a single namespace in the cluster](https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html). For example, if you specified you wanted 2 teams, Terraform will create two IAM Users (team1 and team2) and two Kubernetes namespaces (team1 and team2). The `aws-auth-patch.yaml` file basically tells Kubernetes you want the IAM User `team1` to only have access to the `team1` namespace and `team2` to only have access to the `team2` namespace. This is for security purposes so one team doesn't interfere with another team's namespace.

Note that 10 teams have been hardcoded into this file. I still haven't had time to automate generating this file with a script, so if you will launch the infrastructure for more than 10 teams, feel free to add more entries to the `mapUsers` array (or write a script to automate generating this file, I'd love to see that!). For example:

```
data:
  mapUsers: |
    - userarn: arn:aws:iam::ACCOUNT_ID:user/team1
      username: team1
      groups:
        - team1-role
(...)
    - userarn: arn:aws:iam::ACCOUNT_ID:user/team9
      username: team9
      groups:
        - team9-role
    - userarn: arn:aws:iam::ACCOUNT_ID:user/team10
      username: team10
      groups:
        - team10-role
    - userarn: arn:aws:iam::ACCOUNT_ID:user/team11 <-- NEW ENTRY
      username: team11
      groups:
        - team11-role
    - userarn: arn:aws:iam::ACCOUNT_ID:user/team12 <-- NEW ENTRY
      username: team12
      groups:
        - team12-role
```

**PS: you don't need to replace `ACCOUNT_ID`. The script will do that automatically based on the AWS profile you specified.**

**One more thing...** the deploy script is likely to run on Linux as is. However, you will probably need to change the `sed` command since the macOS implementation of `sed` is a bit different than the implementation for Linux. But apart from that, you shouldn't need to change the deploy script too much to run it on Linux.

That's it! When you're ready, run `./deploy-infra.sh`.

# Destroying the infrastructure

Simply run `./destroy-infra.sh` and it should all be destroyed!

# Support

If you run into issues running the deploy script, open an issue or PR here on GitHub or DM me on [Twitter](https://twitter.com/DojoWithRenan) (@DojoWithRenan). I appreciate your interest in this repository!
