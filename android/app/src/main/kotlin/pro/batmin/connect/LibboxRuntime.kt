package pro.batmin.connect

/**
 * Runtime probe for the generated gomobile libbox bindings.
 *
 * Batmin Connect uses the CommandServer API exposed by the pinned libbox:
 *
 *   Libbox.checkConfig(String)
 *   Libbox.newCommandServer(CommandServerHandler, PlatformInterface)
 *
 * Older probes expected newService(), which is not part of this libbox API.
 */
object LibboxRuntime {

    private val candidateClassNames = listOf(
        "io.nekohasekai.libbox.Libbox",
        "libbox.Libbox"
    )

    data class Probe(
        val available: Boolean,
        val className: String? = null,
        val publicMethods: List<String> = emptyList(),
        val message: String
    )

    fun probe(): Probe {
        for (name in candidateClassNames) {
            val clazz = try {
                Class.forName(name)
            } catch (_: ClassNotFoundException) {
                continue
            } catch (error: Throwable) {
                return Probe(
                    false,
                    message = "Ошибка загрузки $name: ${error.message}"
                )
            }

            val methods = clazz.methods
                .map { method ->
                    val args = method.parameterTypes.joinToString(",") {
                        it.simpleName
                    }
                    "${method.name}($args):${method.returnType.simpleName}"
                }
                .distinct()
                .sorted()

            val hasConfigCheck = methods.any {
                it.startsWith("checkConfig(") ||
                it.startsWith("CheckConfig(")
            }

            val hasCommandServerFactory = methods.any {
                it.startsWith("newCommandServer(") ||
                it.startsWith("NewCommandServer(")
            }

            val compatible = hasConfigCheck && hasCommandServerFactory

            return Probe(
                available = compatible,
                className = name,
                publicMethods = methods,
                message = if (compatible) {
                    "libbox готов: checkConfig/newCommandServer доступны"
                } else {
                    "libbox найден, но API checkConfig/newCommandServer неполный"
                }
            )
        }

        return Probe(
            false,
            message = "libbox.aар отсутствует или класс Libbox недоступен"
        )
    }
}
