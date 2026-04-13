# Estrategia de Branching

## Metodología ágil: Kanban

Este proyecto utiliza **Kanban** como metodología ágil. El trabajo se gestiona
mediante un tablero con columnas (Backlog → En Progreso → Revisión → Listo) y
límites de WIP para evitar cuellos de botella.

---

## 1. Estrategia para desarrolladores — Gitflow

Gitflow define un modelo estructurado de ramas para gestionar el ciclo de vida
completo del desarrollo: desde la creación de features hasta releases y hotfixes
en producción.

### Ramas permanentes

| Rama | Propósito | Protección |
|------|-----------|------------|
| `main` | Código en producción. Cada commit representa una versión desplegada. | Solo merges desde `develop/*` o `hotfix/*` vía PR aprobado |
| `develop` | Rama de integración. Convergen todas las features antes de un release. | Solo merges desde `feature/*` o `release/*` vía PR |

### Ramas de soporte (temporales)

| Rama | Origen | Destino | Ciclo de vida |
|------|--------|---------|--------------|
| `feature/<nombre>` | `develop` | `develop` | Dura mientras se desarrolla la feature. Se elimina al hacer merge. |
| `release/<version>` | `develop` | `main` + `develop` | Solo bugfixes. Se elimina al publicar. |
| `hotfix/<nombre>` | `main` | `main` + `develop` | Solo para fixes urgentes en producción. |

### Flujo típico

```
1. git checkout develop
   git checkout -b feature/add-vote-validation

2. git commit -m "feat: add input validation to vote endpoint"

3. Pull Request: feature/add-vote-validation → develop
   - Requiere al menos 1 aprobación
   - El pipeline de CI debe pasar

4. Merge a develop → CI corre automáticamente
```

### Convenciones de nombres

```
feature/   → nueva funcionalidad       ej: feature/result-websocket-reconnect
bugfix/    → corrección en develop      ej: bugfix/kafka-timeout-handling
hotfix/    → fix urgente en producción  ej: hotfix/vote-null-pointer-exception
release/   → preparación de versión     ej: release/1.2.0
```

---

## 2. Estrategia para operaciones — GitOps

GitOps aplica los principios de Git al manejo de infraestructura: el estado del
cluster de Kubernetes debe reflejar exactamente lo que está en la rama de
infraestructura. Cualquier cambio a la infraestructura pasa por Git, nunca
directamente al cluster.

### Ramas permanentes de operaciones

| Rama | Propósito | Ambiente |
|------|-----------|----------|
| `infra/main` | Estado de infraestructura en producción. | Producción |
| `infra/staging` | Cambios de infraestructura en validación. | Staging |

### Flujo de un cambio de infraestructura

```
1. git checkout infra/staging
   git checkout -b infra/feature/increase-worker-replicas

2. Modificar Helm charts o values.yaml

3. Pull Request: infra/feature/... → infra/staging
   - El pipeline corre helm lint en todos los charts
   - Se despliega automáticamente a staging para validación

4. Verificar que el cambio funciona en staging

5. Pull Request: infra/staging → infra/main
   - Requiere aprobación manual
   - El pipeline despliega a producción al hacer merge
```

### Archivos gestionados por GitOps

```
infrastructure/          ← Helm chart de Kafka + PostgreSQL
  values.yaml

vote/chart/              ← Helm chart del servicio vote
result/chart/            ← Helm chart del servicio result
worker/chart/            ← Helm chart del servicio worker
  values.yaml            ← configuración de cada servicio
```

---

## Reglas generales

1. **Nunca hacer push directo a `main` o `infra/main`** — siempre vía Pull Request
2. **Los PRs a `main` e `infra/main` requieren al menos 1 aprobación**
3. **El pipeline de CI debe estar en verde** antes de hacer merge
4. **Commits siguen Conventional Commits:**
   - `feat:` nueva funcionalidad
   - `fix:` corrección de bug
   - `chore:` mantenimiento
   - `docs:` solo documentación
   - `ci:` cambios en pipelines
   - `infra:` cambios de infraestructura

## Resumen de todas las ramas

```
DESARROLLO (Gitflow)              OPERACIONES (GitOps)
─────────────────────             ─────────────────────
main           (producción)       infra/main      (infra producción)
develop        (integración)      infra/staging   (infra staging)
feature/*      (nuevas features)  infra/feature/* (cambios de infra)
release/*      (preparación)
hotfix/*       (fixes urgentes)
```
