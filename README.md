# compasstorch

Brújula con un mando deslizable para la linterna y el "modo faro". Flutter,
Android e iOS.

## Qué hace

La pantalla se divide en dos mitades:

- **Arriba, la brújula.** Cambia de forma según cómo se sujete el teléfono:
  - **En horizontal** (tumbado, como se lee una brújula de verdad): rosa de los
    vientos que gira, con la aguja marcando el norte magnético.
  - **En vertical** (levantado, apuntando a algo): una regla de líneas
    verticales que se desplaza con el rumbo al que apunta la parte trasera del
    teléfono, con los grados marcados y la elevación sobre el horizonte.

  El cambio lo decide la inclinación del plano del teléfono (`tilt`), con una
  banda muerta entre 35° y 55° para que la vista no oscile en el límite.

- **Abajo, el mando.** Un pulsador que descansa en la esquina inferior derecha
  y se arrastra en dos ejes independientes:
  - **Hacia arriba** → enciende la linterna (flash).
  - **Hacia la izquierda** → activa el **modo faro**: tema claro, brillo al
    máximo y la pantalla no se apaga sola.
  - **En diagonal**, hacia la esquina superior izquierda, quedan las dos
    activas. Devolver el pulsador a su esquina las apaga.

  También se puede tocar directamente la esquina a la que se quiere llevar el
  pulsador.

La aplicación usa **tema oscuro** siempre, salvo mientras el modo faro está
activo, que es cuando pasa a blanco para que la pantalla dé el máximo de luz.

## Cómo se calcula el rumbo

No se usa ningún plugin de brújula: la orientación se deriva del acelerómetro y
el magnetómetro (`sensors_plus`) reproduciendo el cálculo de
`SensorManager.getRotationMatrix` de Android. Con el vector de gravedad y el del
campo magnético se construye la matriz de rotación del dispositivo respecto al
mundo (X = este, Y = norte magnético, Z = arriba) y de ahí salen los tres datos
que necesita la interfaz: el rumbo del borde superior, el rumbo de la cámara
trasera y la inclinación.

Ambas lecturas pasan por un filtro paso bajo para que la aguja no tiemble.

**El norte es el magnético**: no se aplica corrección de declinación, así que
puede diferir unos grados del norte geográfico según la zona. Como cualquier
brújula de móvil, necesita calibrarse moviendo el teléfono en forma de ocho, y
se desvía cerca de metales o imanes.

## Dependencias

| Paquete | Para qué |
| --- | --- |
| `sensors_plus` | Acelerómetro y magnetómetro (rumbo e inclinación) |
| `torch_light` | Encender y apagar el flash |
| `screen_brightness` | Brillo al máximo, solo dentro de la aplicación |
| `wakelock_plus` | Impedir que la pantalla se apague |

`torch_light` usa `CameraManager.setTorchMode` en Android, que **no** requiere el
permiso `CAMERA`. `screen_brightness` cambia el brillo únicamente de esta
aplicación, así que tampoco necesita `WRITE_SETTINGS`. En iOS los sensores de
movimiento no piden permiso, pero se declara `NSMotionUsageDescription`.

## Desarrollo

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Los tests cubren el cálculo de la orientación con vectores conocidos (teléfono
tumbado y levantado apuntando a cada rumbo, caída libre, campo alineado con la
gravedad), los gestos del mando y la lógica de los dos controles con un doble de
`DeviceServices`, sin tocar los canales de plataforma.
