# Microservices Demo — Taller 1: Pipelines en Cloud

Aplicación de votación distribuida construida con Java, Go, Node.js, Kafka y PostgreSQL.
Desarrollada como parte del Taller 1 de construcción de pipelines en cloud.

## Arquitectura

![Architecture diagram](architecture.png)

| Servicio | Tecnología | Descripción |
|----------|-----------|-------------|
| [vote](./vote) | Java / Spring Boot | Frontend de votación. Recibe votos y los publica en Kafka. |
| [worker](./worker) | Go | Consume votos de Kafka y los persiste en PostgreSQL. |
| [result](./result) | Node.js | Lee los conteos de PostgreSQL y los muestra en tiempo real. |
| Kafka | apache/kafka:3.7.0 | Cola de mensajes que desacopla vote y worker. |
| PostgreSQL | postgres:16 | Base de datos de resultados. |

## Documentación

- [Informe del Taller](./docs/informe.md) — Documentación completa con evidencias
- [Estrategia de Branching](./docs/branching-strategy.md) — Gitflow para desarrollo, GitOps para operaciones
- [Patrones de Diseño de Nube](./docs/cloud-patterns.md) — 5 patrones implementados y documentados

## Pipelines CI/CD

| Workflow | Trigger | Descripción |
|----------|---------|-------------|
| Vote CI | Push a `develop`, `feature/**` con cambios en `vote/` | Build, test y docker push del servicio vote |
| Worker CI | Push a `develop`, `feature/**` con cambios en `worker/` | Build, vet y docker push del servicio worker |
| Result CI | Push a `develop`, `feature/**` con cambios en `result/` | Install, audit y docker push del servicio result |
| Infrastructure CI | PR a `main` o `infra/main` | Helm lint y template validation de todos los charts |
| Deploy | Push a `main` | Valida charts y genera resumen de imágenes listas |

## Ejecución local con kind

### Prerrequisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)

### 1. Crear el cluster

```bash
kind create cluster --name microservices-demo
```

### 2. Desplegar la aplicación

```bash
bash scripts/deploy-local.sh electromayonaise develop
```

### 3. Acceder a la aplicación

```bash
# App de votación
kubectl port-forward svc/vote 9090:8080
# Abrir http://localhost:9090

# Resultados en tiempo real
kubectl port-forward svc/result 9091:80
# Abrir http://localhost:9091
```

### 4. Verificar el estado del cluster

```bash
kubectl get pods
kubectl get configmaps
```

## Estrategia de branching

```
DESARROLLO (Gitflow)              OPERACIONES (GitOps)
─────────────────────             ─────────────────────
main           (producción)       infra/main      (infra producción)
develop        (integración)      infra/staging   (infra staging)
feature/*      (nuevas features)  infra/feature/* (cambios de infra)
release/*      (preparación)
hotfix/*       (fixes urgentes)
```

## Notas

- La aplicación solo acepta un voto por cliente. Para cambiar el voto hay que seleccionar la otra opción.
- Las imágenes Docker se publican automáticamente en `ghcr.io/electromayonaise/microservices-demo/`.
