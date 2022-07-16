# Kind kubernetes with local registry

Run your images in local kubernetes.

# Requirements
 - [Docker](https://docs.docker.com/get-docker/)
 - [Kubectl](https://kubernetes.io/docs/tasks/tools/)
 - [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

# Get started

- Clone the repository
```
    # SSH
    git clone git@github.com:Puglielli/kind-kubernetes-with-registry.git

    # HTTP
    git clone https://github.com/Puglielli/kind-kubernetes-with-registry.git
```

- Creating resources
    
    - Using `make`
    ```
        make create_all  
    ```

    - Creating the resources separately
        
        - Creating the Registry container
        ```
            docker run -d --restart=always -p 127.0.0.1:5001:5000 --name k8s-registry registry:2
        ```

        - Creating Kubernetes
        ```
            kind create cluster --config k8s_with_registry.yaml --name k8s
        ```

        - Creating Configmap
        ```
            CM_NAME=k8s-registry-cm REGISTRY_EXPORT_PORT=5001 REGISTRY_PORT=5000 envsubst < ./configmap.yaml | kubectl apply -f -
        ```

        - Connecting Kind's network to Registry
        ```
            docker network connect kind k8s-registry
        ```

- Deleting created resources

    - Using `make`
    ```
        make clean_up
    ```

    - Deleting resources separately
        
        - Deleting the Registry container
        ```
            # First retrieve from the container the name of the volume it is using
            volume_name=$(docker inspect k8s-registry -f '{{ (index .Mounts 0).Name }}')

            docker stop k8s-registry
            docker rm k8s-registry
		    docker volume rm $volume_name
            docker image rm registry:2
        ```
        
        - Deleting Kubernetes
        ```
            kind delete cluster --name k8s
            docker network rm kind
        ```