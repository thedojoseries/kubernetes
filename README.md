# Challenge
In this challenge, you will have to deploy a TODO application to a Kubernetes cluster which will be provided to you. This application comprises of seven microservices written in different programming languages. It was not developed by us at Slalom. It's an open-source project, which you can find it in this Github repository: [https://github.com/elgris/microservice-app-example](https://github.com/elgris/microservice-app-example).

Notice that there is a folder called **k8s** where you can find deployment and service definition files for each microservice. These files can be used as a starting point, but you will need to modify them according to the technical requirements of this challenge.

**PS: The version of the Kubernetes cluster you will be deploying to is 1.9.7. Hence, refer to this version of the [Kubernetes API Documentation](https://v1-9.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.9/).**

It's also worth noting that Docker images will not need to be built. We've already done that for you and you can find the URLs of the images in the technical requirements.

The next sections will explain the architecture of the application, technical requirements, step-by-step how to solve the challenge and how to get access to the Kubernetes cluster.

# Architecture
This is the final architecture of the application once it's running on Kubernetes:

![Architecture](https://s3.ca-central-1.amazonaws.com/slalom-public-images/application-architecture.png)

Here's a summary of the architecture:

* There will be two public services: Zipkin and Frontend
* Both Zipkin and Frontend will be served by only one Load Balancer
* A few services will need to be configured via Environment Variables (Frontend, TODOs API, Auth API, Log Message and Users API)
* Services can communicate internally with other services via private DNS names
* The Redis Queue service will persist its data in a persistent disk that sits outside the cluster

# Technical Requirements
This section presents a few technical requirements to which your final solution need to adhere:

## 1) Shared cluster

**Each cluster will be shared between two teams**. This means both teams will have to create and deploy resources to their own [Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/). In Kubernetes, if you do not specify a namespace when deploying a resource, the resource is deployed to the **default** namespace. Since there will be two teams working on the same cluster, in order to avoid overwriting each other's work, two separate namespaces will need to be created. You can name them as you wish, but as a suggestion, use the name of your team (team1, team2, team3 etc).

**PS: Do not deploy to the default namespace of the cluster. Resources deployed to the default namespace will be deleted.**

## 2) Docker images
As already mentioned, you will not need to generate Docker images for each microservice. That has already been done for you. Please use the following images:

* Frontend: **slalomdojo/frontend**
* Auth API: **slalomdojo/auth-api**
* Log Message Processor: **slalomdojo/log-message-processor**
* Redis Queue: **redis**
* TODOs API: **slalomdojo/todos-api**
* Users API: **slalomdojo/users-api**
* Zipkin: **openzipkin/zipkin**

## 3) Environment Variables as Secrets/ConfigMaps
Most of the applications will need to be configured via environment variables. However, you should not declare these variables in the Pod/Deployment definition file like in the [repository](https://github.com/elgris/microservice-app-example). Use [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) or [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) instead.

## 4) Health Checks
When deploying microservices to Kubernetes, it's important to implement health checks to tell the cluster whether your application is healthy or not. However, You do not have to touch the code to implement a health check path because that's already been done for some of the services. Use [Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/) to tell Kubernetes when a microservice is healthy. Here's how you should configure each app (things like failure and success thresholds, delay etc is):

* Auth API: HTTP GET on port 8081; path /version
* Frontend: HTTP GET on port 8080; path /
* Redis Queue: TCP Socket on port 6379
* TODOs API: HTTP GET on port 8082; path /health
* Users API: TCP Socket on port 8083
* Zipkin: HTTP GET on port 9411; path /health

**You do not need to configure health checks for the Log Message Processor service.**

## 5) Two subdomains, one Load Balancer, two applications
There should be only one Load Balancer serving both Zipkin and Frontend services. The URLs for each service should be:

* **Frontend**: frontend.teamX.slalomdev.io
* **Zipkin**: zipkin.teamX.slalomdev.io

These DNS records should be created automatically for you as long as you specify them in the right definition file. Naturally, you will have to replace **X** with the number of your team. For example, if you are in team 1, your frontend URL will be **frontend.team1.slalomdev.io**.
If you are having trouble with these URLs not being resolved, please reach out to one of the organizers.

Ingress vs Services

Although you can use [Services](https://kubernetes.io/docs/concepts/services-networking/service/) to expose applications to the Internet via Load Balancers, for this challenge use [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) instead. Ingress resources are powerful as it allows you to smartly route traffic to multiple services. If you read the documentation, you will notice that you need an Ingress Controller before you can deploy Ingress resources. **Your cluster already has an Ingress Controller that we deployed for you. Take a look at the pods in the ingress namespace.** (This is the Ingress Controller implementation we are using)[https://github.com/kubernetes/ingress-nginx].
To link your Ingress resource to the controller that has been deployed, use the following piece of code in the Ingress definition file:

```
kind: Ingress
metadata:
    annotations:
        kubernetes.io/ingress.class: "default"
```

The annotation above tells Kubernetes that this Ingress belongs to the class **default**, which is the same class as the Ingress Controller. That should be enough to route the external traffic to the service you associate with the Ingress.

## 6) Persisting Redis data

As you probably are aware, if you save data in a container and this container is killed, the data will not be persisted in any way. However, for this challenge, all Redis data should be saved in a persistent disk. Using a persistent disk will make sure the container can be killed or restarted without losing the data.

Your Kubernetes cluster already contains a [Storage Class](https://kubernetes.io/docs/concepts/storage/storage-classes/#gce) called **standard** (run *kubectl get sc*). This means that whenever you create a [Persistent Volume Claim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) using the **standard** storage class, your cluster will communicate with the underlying cloud provider so a persistent disk is created for you. Also, when creating the Persistent Volume Claim, you will have to specify the size of the disk. Please use 2GB. We have already tested and 2GB is enough for this challenge. If you provide over 5GB of storage, the organizers will have to delete the disk.

## 7) Network Policies
One of the security best practices when running applications on Kubernetes is to restrict inbound and outbound traffic based on the principle of least privilege (i.e., pods should only be able to communicate with a selected pods). In order to implement that, use [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/). Follow the bullet points below to guide you through developing your Network Policies:

### General
* ALLOW **egress** on port 53 and protocols TCP and UDP in all pods in the default namespace

### Auth API
* ALLOW **ingress** on port 8081 from Frontend
* ALLOW **egress** to both Users API (on port 8083) and Zipkin (on port 9411)

### Frontend
* ALLOW **ingress** from all sources
* ALLOW **egress** to Auth API (on port 8081), TODOs API (on port 8082) and Zipkin (on port 9411)

### Log Message Processor
* DENY **ingress** from all sources
* ALLOW **egress** to Redis Queue (on port 6379) and Zipkin (on port 9411)

### Redis Queue
* ALLOW **ingress** on port 6379 from TODOs API and Log Message Processor

### TODOs API
* ALLOW **ingress** on port 8082 from Frontend
* ALLOW **egress** to Redis Queue (on port 6379) and Zipkin (on port 9411)

### Users API
* ALLOW **ingress** on port 8083 from Auth API
* ALLOW **egress** to Zipkin (on port 9411)

### Zipkin
* ALLOW **ingress** from all sources
* DENY **egress** to all destination

# Getting Started

All you need to get started is Docker! We have already prepared a Docker image with **kubectl** configured for you. However, note that if you run kubectl inside the container but you are developing definition files outside the container (in your local machine), you will not be able to deploy these files. You will have to mount a volume into the container so kubectl can have access to your files. First, cd into the directory where your files will be, then run the following docker command to get started:

```
docker run --rm -it -e "URL1=<URL1>" -e "URL2=<URL2>" -v $PWD:/code slalomdojo/env
```

**PS 1: The command above is primarily for Mac and Linux users. If you are a Windows user, you will have to replace $PWD with the full path of your directory.**

**PS 2: By mounting the volume, all changes you make in your local machine will be automatically propagated to the container. Use your local machine to develop the definition files.**

**PS 3: You will notice that you need to specify two environment variables: URL1 and URL2. You will be given further instructions at the start of the challenge.**

Once the command runs, you will be inside the container and your code will be in the **/code** directory. Also, if you run **kubectl get nodes** you should be able to see two nodes registered with the cluster.

If there's any issue with your environment, please let one of the organizers know.

------

# Solving the challenge step-by-step

We understand that this might be your first time working with Kubernetes. Therefore, we'd like to offer you some help. The next sections will show you how to solve most of this challenge step-by-step. We will not provide the solution, but we will point you at the right direction.

**PS: event after following all the steps below, your solution will not be complying with all the technical requirements. This is just to show you a natural approach to deploying applications to Kubernetes. You will still need to implement more things.**

## Step 0: kubectl

Familiarize yourself with [kubectl](https://kubernetes.io/docs/reference/kubectl/overview/) and head over to the [Kubernetes API Documentation](https://v1-9.docs.kubernetes.io/docs/reference/generated/kubernetes-api/v1.9/). The API Documentation will help you build all the definition files you will need.

## Step 1: Create a namespace

Before you start deploying resources, create a [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/). To make things easier, use your team's name for the namespace.

## Step 2: Deploying containers to Kubernetes

If this is your first time working with Kubernetes, clone the [Microservice App Example repository](https://github.com/elgris/microservice-app-example) to your local machine. As mentioned in the beginning of the challenge, there's a k8s folder where you can find [Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) and [Service](https://kubernetes.io/docs/concepts/services-networking/service/) definition files for each of the seven microservices. As a first step, try to use *kubectl* to launch [Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/) (one microservice = one Pod). At this point, some containers might be failing (e.g. log message processor), but don't worry as it will be fixed in a later step.

## Step 3: Environment Variables

The containers you deployed already contain all the environment variables needed by each microservice. However, let's use either [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) or [ConfigMaps](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) to provide these applications with the environment variables. 
For each deployment file that contains the **env** key, delete all environment variables and move them to a new file (which will be either a Secret or a ConfigMap). Once that's done, deploy the new resources and restart all pods to make sure it worked (restarting means killing the pod with the `kubectl delete pod` command).

## Step 4: Health Checks

Configure Health Checks. Have a look at [Liveness and Readiness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/).

## Step 5: Service communication

Now that all the applications are correctly configured, they need to communicate with each other. In Kubernetes, each Pod receives an IP address. If you have 3 Pods of the same application, there will be 3 IP addresses that other applications can use to communicate with these Pods. However, in a dynamic environment where Pods go up and down, you do not want to keep track of IP addresses. To solve that, use [Services](https://kubernetes.io/docs/concepts/services-networking/service/).

## Step 6: Public microservices

Both Zipkin and Frontend need to be reachable through the Internet. In the diagram you will see that you will need a Load Balancer in front of both apps. However, you will not need to launch a Load Balancer yourself. Use [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) for that. Also, note that we've already deployed the Ingress Controller with a class named **default**.

If you are confused whether you should use ClusterIP, NodePort, LoadBalancer or Ingress, [take a look at this article](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0).

## Step 7: Persist Redis data to a persistent disk

If you exec into the redis container, run *redis-cli* and set a key (e.g., *set devops cool*), you will notice that if you restart the pod, exec into it again and get the keys in Redis again, they will all be gone. That's because data is being persisted only inside the container. Take a look at [Persistent Volume Claim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims) and read Requirement 6.

## Step 8: Pod security

Requirement 7 should have all the info you need for this step.

### Good luck to all teams!
