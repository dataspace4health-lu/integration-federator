timestamp = $(shell date "+%Y.%m.%d-%H.%M.%S")

define build =
make clean -C ../helm-identity-and-trust/
make build -C ../helm-identity-and-trust/
cp ../helm-identity-and-trust/helm/identity-and-trust-*.*.*.tgz .

make clean -C ../helm-federated-catalogue/
make build -C ../helm-federated-catalogue/
cp ../helm-federated-catalogue/helm/federated-catalogue-*.*.*.tgz .
endef

define test =
mkdir -p tests/results/${timestamp}
docker run -d -t --name playwright --ipc=host mcr.microsoft.com/playwright:v1.46.1
docker exec playwright bash -c "mkdir -p app/tests"
docker cp tests playwright:/app
-docker exec playwright bash -c "cd /app/tests && export CI=1 && npm i --silent && npx -y playwright test --output ./results"
if [ $$? -eq 0 ]; then \
	docker cp playwright:/app/tests/results/ tests/results/${timestamp}/traces; \
	docker cp playwright:/app/tests/playwright-report/ tests/results/${timestamp}/report; \
fi
docker rm -f playwright
endef

.PHONY: all build install test uninstall clean

all: build install test uninstall clean

build:
	$(build)

install:
	helm install iat identity-and-trust-1.0.0.tgz -f identity-and-trust.yaml
	helm install fcat federated-catalogue-1.0.0.tgz -f federated-catalogue.yaml
test:
	$(test)

uninstall:
	docker delete pod playwright 2> /dev/null || true

	helm uninstall iat

	kubectl delete pvc iat-issuer-api-data 2> /dev/null || true
	kubectl delete pvc data-iat-iam-postgresql-0 2> /dev/null || true
	kubectl delete pvc data-iat-wallet-api-vault-server-0 2> /dev/null || true
	kubectl delete pvc iat-wallet-api-data 2> /dev/null || true
	kubectl delete pvc data-iat-wallet-api-postgresql-0 2> /dev/null || true

	helm uninstall fcat

	kubectl delete pvc data-fcat-service-neo4j-0 2> /dev/null || true
	kubectl delete pvc data-fcat-service-postgresql-0 2> /dev/null || true
	kubectl delete pvc data-fcat-service-keycloak-postgresql-0 2> /dev/null || true

clean:
	rm -rf ./*.tgz