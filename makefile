K8S_NAME ?= k8s
K8S_KIND_FILE ?= k8s_with_registry.yaml

CM_NAME ?= k8s-registry-cm

HOST ?= 127.0.0.1
REGISTRY_IMAGE ?= registry:2
REGISTRY_NAME ?= k8s-registry
REGISTRY_PORT ?= 5000
REGISTRY_EXPORT_PORT ?= 5001

K8S_DIR ?= .
REGEX_FILES ?= '.*\.(txt|text)$$'


create_registry:
	$(eval exists=$(shell docker inspect -f '{{ .State.Running }}' ${REGISTRY_NAME} 2>/dev/null))

	@if [ -z ${exists} ]; then \
		docker run -d --restart=always -p "${HOST}:${REGISTRY_EXPORT_PORT}:${REGISTRY_PORT}" --name "${REGISTRY_NAME}" ${REGISTRY_IMAGE} ;\
	else \
		echo "Registry already exist" ;\
	fi

connect_registry:
	$(eval exists=$(shell docker inspect -f='{{json .NetworkSettings.Networks.kind}}' ${REGISTRY_NAME} 2>/dev/null || null))

	@if [[ -z ${exists} || ${exists} == 'null' ]]; then \
		docker network connect kind ${REGISTRY_NAME} ;\
	else \
		echo "Network is already connected to the kind" ;\
	fi


delete_kubernetes:
	@kind delete cluster --name ${K8S_NAME}

create_kubernetes:
	$(eval exists=$(shell kind get clusters | grep -c ${K8S_NAME}))

	@if [ ${exists} == "0" ]; then \
		kind create cluster --config ${K8S_KIND_FILE}  --name ${K8S_NAME} ;\
		kubectl config set-context ${K8S_NAME} ;\
		make create_config_map ;\
		make connect_registry ;\
	else \
		echo "Kubernetes already exist" ;\
	fi

create_config_map:
	$(eval exists=$(shell kubectl get cm -A | grep -c ${CM_NAME}))

	@if [ ${exists} == "0" ]; then \
		CM_NAME=${CM_NAME} REGISTRY_EXPORT_PORT=${REGISTRY_EXPORT_PORT} REGISTRY_PORT=${REGISTRY_PORT} envsubst < ./configmap.yaml | kubectl apply -f - ;\
	else \
		echo "Configmap already exist" ;\
	fi

replace_variables_in_files:
	@find -E ${K8S_DIR} -regex ${REGEX_FILES} -exec bash -c 'envsubst < {} > {}_ && mv {}_ {} | echo "The variables from the {} file replaced"' \;

create_all:
	@make create_registry
	@make create_kubernetes

clean_up:
	$(eval volume_name=$(shell docker inspect ${REGISTRY_NAME} -f '{{ (index .Mounts 0).Name }}' 2>/dev/null))

	@if [ ! -z ${volume_name} ]; then \
		docker stop ${REGISTRY_NAME} ;\
		docker rm ${REGISTRY_NAME} ;\
		docker volume rm ${volume_name} ;\
	else \
		echo "Registry already deleted" ;\
	fi

	@make delete_kubernetes
	@docker network rm kind
