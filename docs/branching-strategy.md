# Branching Strategy

## Metodología ágil: Kanban

Se utiliza **Kanban** como metodología ágil. El tablero de trabajo gestiona las tareas en columnas
(Backlog → In Progress → Review → Done), con límites de trabajo en progreso (WIP limits) para evitar
cuellos de botella. Kanban es apropiado para este proyecto porque los cambios son continuos y no
se trabaja en sprints fijos.

---

## 1. Estrategia de Branching para Desarrolladores — Gitflow

Gitflow define un modelo estructurado de ramas para gestionar el ciclo de vida completo del
desarrollo de software: desde la creación de features hasta los releases y hotfixes en producción.

### Ramas permanentes

| Rama | Propósito | Protección |
|------|-----------|------------|
| `main` | Código en producción. Cada commit aquí representa una versión desplegada. | Solo merges desde `release/*` o `hotfix/*` vía PR aprobado |
| `develop` | Rama de integración. Aquí convergen todas las features terminadas antes de un release. | Solo merges desde `feature/*` o `release/*` vía PR |

### Ramas de soporte (temporales)

| Rama | Origen | Destino | Ciclo de vida |
|------|--------|---------|--------------|
| `feature/<nombre>` | `develop` | `develop` | Dura mientras se desarrolla la feature. Se elimina al hacer merge. |
| `release/<version>` | `develop` | `main` + `develop` | Se crea al preparar un release. Permite solo bugfixes. Se elimina al publicar. |
| `hotfix/<nombre>` | `main` | `main` + `develop` | Solo para fixes urgentes en producción. Se elimina al resolver. |

### Flujo típico de un desarrollador

```
1. Crear rama desde develop:
   git checkout develop
   git checkout -b feature/add-vote-validation

2. Desarrollar y hacer commits:
   git add .
   git commit -m "feat: add input validation to vote endpoint"

3. Abrir Pull Request: feature/add-vote-validation → develop
   - Requiere revisión de al menos 1 persona
   - El pipeline de CI debe pasar (build + tests)

4. Merge a develop → CI corre automáticamente

5. Cuando hay suficientes features para un release:
   git checkout -b release/1.2.0 develop
   # Solo bugfixes aquí
   git checkout main && git merge release/1.2.0
   git tag v1.2.0
   git checkout develop && git merge release/1.2.0
```

### Convenciones de nombres

```
feature/   → nueva funcionalidad         ej: feature/result-websocket-reconnect
bugfix/    → corrección de bug en dev    ej: bugfix/kafka-timeout-handling
hotfix/    → fix urgente en producción   ej: hotfix/vote-null-pointer-exception
release/   → preparación de versión      ej: release/1.2.0
```

### Diagrama

```
main        ────────────────────────────────●────────────────────────●──────
                                           ↑ merge release/1.1.0    ↑ merge hotfix/...
                                          /                         /
release/1.1.0             ──────────────●
                         /               (bugfixes only)
develop     ────●────────●──────────────────●──────────────────────────────
              ↑ merge  ↑ branch release   ↑ merge feature/B
feature/A   ──●──●──●──╯
feature/B                 ──────●──●──────╯
hotfix/x                                              ─────●────────────────
                                                           ↑ branch from main
```

---

## 2. Estrategia de Branching para Operaciones — GitOps

GitOps aplica los principios de Git al manejo de infraestructura: el estado del cluster de
Kubernetes debe reflejar exactamente lo que está en la rama de infraestructura. Cualquier
cambio a la infraestructura pasa por Git, nunca directamente al cluster.

Los cambios de infraestructura (Helm charts, valores de configuración) se gestionan en ramas
separadas del código de aplicación para mantener ciclos de vida independientes.

### Ramas permanentes de operaciones

| Rama | Propósito | Corresponde a |
|------|-----------|--------------|
| `infra/main` | Estado de infraestructura en producción. El cluster de producción sincroniza desde aquí. | Ambiente de producción |
| `infra/staging` | Cambios de infraestructura en validación. Se prueban aquí antes de promover a prod. | Ambiente de staging |

### Flujo de un cambio de infraestructura

```
1. Crear rama desde infra/staging:
   git checkout infra/staging
   git checkout -b infra/feature/increase-worker-replicas

2. Modificar los Helm charts o values:
   # Editar worker/chart/values.yaml, infrastructure/values.yaml, etc.

3. Pull Request: infra/feature/... → infra/staging
   - El pipeline corre helm lint sobre todos los charts
   - Se despliega automáticamente a staging para validación

4. Verificar en staging que el cambio funciona correctamente

5. Pull Request: infra/staging → infra/main
   - Requiere aprobación manual (cambio de producción)
   - El pipeline despliega a producción al hacer merge
```

### Separación de responsabilidades

```
Desarrolladores trabajan en:         Operaciones trabaja en:
  main                                 infra/main
  develop                              infra/staging
  feature/*                            infra/feature/*
  release/*
  hotfix/*

Los cambios de app suben por:        Los cambios de infra suben por:
  feature → develop → release → main   infra/feature → infra/staging → infra/main
```

### Qué va en cada rama de operaciones

Los archivos que gestiona la estrategia GitOps son:

```
infrastructure/          ← Helm chart de Kafka + PostgreSQL
  values.yaml            ← versiones de imágenes, recursos, replicas

vote/chart/              ← Helm chart del servicio vote
result/chart/            ← Helm chart del servicio result
worker/chart/            ← Helm chart del servicio worker
  values.yaml            ← cada uno con su configuración deployable
```

---

## Reglas generales (ambas estrategias)

1. **Nunca hacer push directo a `main` o `infra/main`** — siempre vía Pull Request
2. **Los PRs a `main` e `infra/main` requieren al menos 1 aprobación**
3. **El pipeline de CI debe estar en verde** antes de hacer merge
4. **Los commits siguen Conventional Commits:**
   - `feat:` nueva funcionalidad
   - `fix:` corrección de bug
   - `chore:` mantenimiento (dependencias, configuración)
   - `docs:` solo documentación
   - `ci:` cambios en pipelines
   - `infra:` cambios de infraestructura

## Resumen visual de todas las ramas

```
DESARROLLO (Gitflow)              OPERACIONES (GitOps)
─────────────────────             ─────────────────────
main          (producción)        infra/main     (infra producción)
develop       (integración)       infra/staging  (infra staging)
feature/*     (nuevas features)   infra/feature/* (cambios de infra)
release/*     (preparación)
hotfix/*      (urgencias prod)
```
