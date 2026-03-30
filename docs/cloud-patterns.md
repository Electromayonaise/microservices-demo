# Patrones de Diseño de Nube

Este documento describe los patrones de diseño de nube aplicados en este proyecto,
tanto los presentes en la arquitectura original como los implementados como parte
de este taller.

---

## Patrones existentes

### 1. Patrón de Microservicios

**Qué es:** Descomponer una aplicación en servicios pequeños e independientemente
desplegables, cada uno responsable de una capacidad de negocio específica.

**Dónde está en este proyecto:**

| Servicio | Responsabilidad | Lenguaje | Puerto |
|----------|----------------|----------|--------|
| vote     | Recibe votos del usuario via HTTP y los publica en Kafka | Java / Spring Boot | 8080 |
| worker   | Consume votos de Kafka y los persiste en PostgreSQL | Go | — |
| result   | Lee conteos de votos de PostgreSQL y los transmite al browser | Node.js | 80 |

Cada servicio tiene su propio:
- `Dockerfile` — build y runtime independiente
- Helm chart — ciclo de vida de despliegue independiente
- Workflow de GitHub Actions — pipeline de CI independiente

**Beneficio:** Un equipo puede desarrollar, probar y desplegar vote sin tocar
result ni worker. Los fallos están aislados por servicio.

---

### 2. Patrón de Cola de Mensajes / Arquitectura Orientada a Eventos

**Qué es:** Los servicios se comunican de forma asíncrona a través de un broker
de mensajes en lugar de llamadas HTTP directas. El productor (vote) no necesita
saber nada sobre el consumidor (worker).

**Dónde está en este proyecto:**

```
Usuario → vote (HTTP POST) → Kafka topic "votes" → worker → PostgreSQL
```

- **vote** publica un mensaje en el topic `votes` cada vez que el usuario hace click
- **worker** se suscribe al topic `votes` y procesa mensajes de forma independiente
- **Kafka** desacopla los dos servicios: si worker cae, los votos se encolan y se
  procesan cuando se recupera

**Beneficio:** vote y worker están completamente desacoplados. Alto tráfico en
vote no impacta directamente la tasa de procesamiento de worker.

---

### 3. Patrón de Reintentos (Retry)

**Qué es:** Cuando un servicio no puede conectarse a una dependencia, reintenta
indefinidamente en lugar de fallar de inmediato.

**Dónde está en este proyecto:**

En [worker/main.go](../worker/main.go), tanto `openDatabase()` como `getKafkaMaster()`
implementan bucles de reintento infinito:

```go
func openDatabase() *sql.DB {
    for {
        db, err := sql.Open("postgres", psqlconn)
        if err == nil {
            return db
        }
        // reintenta hasta que PostgreSQL esté disponible
    }
}
```

De manera similar, en [result/server.js](../result/server.js):

```js
async.retry(
  { times: 1000, interval: 1000 },
  function(callback) { pool.connect(...) }
)
```

**Beneficio:** Los servicios arrancan en cualquier orden sin fallar. Kubernetes
puede levantar Kafka y PostgreSQL mientras vote, result y worker esperan y reintentan.

---

## Patrones implementados

### 4. Patrón de Externalización de Configuración (Config Externalization)

**Qué es:** Separar la configuración del código de la aplicación. Los valores de
configuración (hosts, puertos, credenciales) se almacenan fuera de la imagen del
contenedor y se inyectan en tiempo de ejecución mediante variables de entorno.

**Problema que resuelve:** Antes de este patrón, la configuración estaba
hardcodeada en el código fuente:

```go
// worker/main.go — hardcodeado antes
const host = "postgresql"
const port = 5432
const user = "okteto"
const password = "okteto"
```

Si el host de la base de datos cambia, habría que construir una nueva imagen Docker.
Con Config Externalization, solo cambia el valor del ConfigMap.

**Cómo está implementado:**

Cada servicio tiene ahora un ConfigMap de Kubernetes en su Helm chart:

```yaml
# worker/chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: worker-config
data:
  KAFKA_BROKER: "{{ .Values.config.kafkaHost }}:{{ .Values.config.kafkaPort }}"
  DB_HOST: "{{ .Values.config.dbHost }}"
  DB_PORT: "{{ .Values.config.dbPort }}"
  DB_NAME: "{{ .Values.config.dbName }}"
```

Los valores se definen en `values.yaml` y se inyectan en el contenedor como
variables de entorno:

```yaml
# worker/chart/templates/deployment.yaml
envFrom:
- configMapRef:
    name: worker-config
```

Para cambiar el host de Kafka en todos los servicios, solo hay que actualizar
`values.yaml` — sin cambio de código, sin rebuild de imagen.

**Archivos modificados:**
- `vote/chart/templates/configmap.yaml` — nuevo
- `worker/chart/templates/configmap.yaml` — nuevo
- `result/chart/templates/configmap.yaml` — nuevo
- `vote/chart/templates/deployment.yaml` — actualizado
- `worker/chart/templates/deployment.yaml` — actualizado
- `result/chart/templates/deployment.yaml` — actualizado
- `vote/chart/values.yaml` — actualizado
- `worker/chart/values.yaml` — actualizado
- `result/chart/values.yaml` — actualizado

---

### 5. Patrón Bulkhead

**Qué es:** Aislar recursos (CPU, memoria) por servicio para que un servicio con
mal comportamiento no pueda consumir todos los recursos del cluster y tumbar a
los demás.

El nombre viene del diseño naval: un barco se divide en compartimentos estancos
(mamparos) para que inundar uno no hunda todo el barco.

**Problema que resuelve:** Sin límites de recursos, una fuga de memoria en el
servicio result podría consumir toda la RAM disponible del nodo, causando que
Kubernetes expulse vote y worker.

**Cómo está implementado:**

El Helm chart de cada servicio define ahora `requests` y `limits` de CPU y memoria:

```yaml
# vote/chart/values.yaml
resources:
  requests:
    cpu: "100m"     # mínimo garantizado
    memory: "256Mi"
  limits:
    cpu: "500m"     # techo máximo
    memory: "512Mi"
```

```yaml
# Aplicado en deployment.yaml
resources:
  requests:
    cpu: {{ .Values.resources.requests.cpu }}
    memory: {{ .Values.resources.requests.memory }}
  limits:
    cpu: {{ .Values.resources.limits.cpu }}
    memory: {{ .Values.resources.limits.memory }}
```

**Asignación de recursos por servicio:**

| Servicio | CPU Request | CPU Limit | Memoria Request | Memoria Limit |
|----------|------------|-----------|----------------|--------------|
| vote     | 100m       | 500m      | 256Mi          | 512Mi        |
| worker   | 100m       | 250m      | 64Mi           | 128Mi        |
| result   | 100m       | 250m      | 128Mi          | 256Mi        |

Worker tiene límites menores porque es un binario Go compilado con huella de
memoria mínima. Vote necesita más por la sobrecarga de la JVM.

**Verificar en el cluster:**
```bash
kubectl describe pod <nombre-del-pod> | grep -A 6 "Limits:"
```

**Archivos modificados:**
- `vote/chart/templates/deployment.yaml` — actualizado
- `worker/chart/templates/deployment.yaml` — actualizado
- `result/chart/templates/deployment.yaml` — actualizado
- `vote/chart/values.yaml` — actualizado
- `worker/chart/values.yaml` — actualizado
- `result/chart/values.yaml` — actualizado
