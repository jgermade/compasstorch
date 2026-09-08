package com.jgermade.compasstorch

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal de plataforma para la linterna, con intensidad regulable.
 *
 * `setTorchMode` solo enciende y apaga. Para graduar la luz hace falta
 * `turnOnTorchWithStrengthLevel`, que existe a partir de Android 13 (API 33) y
 * además exige que la cámara declare más de un nivel en
 * `FLASH_INFO_STRENGTH_MAXIMUM_LEVEL`: hay dispositivos con Android 13 o
 * superior que siguen siendo de encendido y apagado. Por eso `capabilities`
 * informa de si la gradación está disponible y `setTorch` cae al modo binario
 * cuando no lo está.
 */
class TorchController(context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.jgermade.compasstorch/torch"

        private const val ERROR_UNAVAILABLE = "torch_unavailable"
        private const val ERROR_FAILED = "torch_failed"
    }

    private val cameraManager =
        context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val channel = MethodChannel(messenger, CHANNEL)

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> capabilities(result)
            "setTorch" -> setTorch(call, result)
            else -> result.notImplemented()
        }
    }

    private fun capabilities(result: MethodChannel.Result) {
        try {
            val id = flashCameraId()
            if (id == null) {
                result.success(mapOf("available" to false, "gradual" to false))
            } else {
                // Los paréntesis son obligatorios: el infijo `to` liga más
                // fuerte que `>`, así que sin ellos se compara el Pair.
                val gradual = maxLevel(id) > 1
                result.success(mapOf("available" to true, "gradual" to gradual))
            }
        } catch (e: CameraAccessException) {
            result.error(ERROR_UNAVAILABLE, e.message, null)
        }
    }

    private fun setTorch(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: false
        val intensity = (call.argument<Double>("intensity") ?: 1.0).coerceIn(0.0, 1.0)

        try {
            val id = flashCameraId()
            if (id == null) {
                result.error(ERROR_UNAVAILABLE, "El dispositivo no tiene flash.", null)
                return
            }

            val max = maxLevel(id)
            when {
                !enabled -> cameraManager.setTorchMode(id, false)
                // La comprobación de versión va aquí, y no solo dentro de
                // maxLevel(), para que el lint vea que la llamada es segura.
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && max > 1 -> {
                    // Los niveles van de 1 a max: el 0 apagaría la linterna, así
                    // que se reserva el mínimo para la intensidad más baja.
                    val level = Math.round(intensity * max).toInt().coerceIn(1, max)
                    cameraManager.turnOnTorchWithStrengthLevel(id, level)
                }
                else -> cameraManager.setTorchMode(id, true)
            }
            result.success(null)
        } catch (e: CameraAccessException) {
            result.error(ERROR_FAILED, e.message, null)
        } catch (e: IllegalArgumentException) {
            result.error(ERROR_FAILED, e.message, null)
        }
    }

    /** Cámara con flash, preferiblemente la trasera. */
    private fun flashCameraId(): String? {
        val withFlash = cameraManager.cameraIdList.filter { id ->
            cameraManager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
        return withFlash.firstOrNull { id ->
            cameraManager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK
        } ?: withFlash.firstOrNull()
    }

    /** Número de niveles de intensidad; 1 significa solo encendido y apagado. */
    private fun maxLevel(id: String): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return 1
        return cameraManager.getCameraCharacteristics(id)
            .get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1
    }
}
