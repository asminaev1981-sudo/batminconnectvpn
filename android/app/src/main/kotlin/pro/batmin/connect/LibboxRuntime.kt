package pro.batmin.connect

/**
 * Runtime probe for the generated gomobile bindings.
 *
 * Keeping discovery reflective allows the Flutter/Android shell to compile
 * before the large AAR is built. It also prevents a false "engine ready"
 * status when an incompatible AAR is accidentally supplied.
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
                return Probe(false, message = "Ошибка загрузки $name: ${error.message}")
            }

            val methods = clazz.methods
                .map { method ->
                    val args = method.parameterTypes.joinToString(",") { it.simpleName }
                    "${method.name}($args):${method.returnType.simpleName}"
                }
                .distinct()
                .sorted()

            val hasServiceFactory = methods.any {
                it.startsWith("newService(") || it.startsWith("NewService(")
            }
            val hasConfigCheck = methods.any {
                it.startsWith("checkConfig(") || it.startsWith("CheckConfig(")
            }
            val compatible = hasServiceFactory && hasConfigCheck
            return Probe(
                available = compatible,
                className = name,
                publicMethods = methods,
                message = if (compatible) {
                    "libbox обнаружен; API newService/checkConfig доступен"
                } else {
                    "libbox найден, но обязательные методы newService/checkConfig не обнаружены"
                }
            )
        }
        return Probe(false, message = "libbox.aar отсутствует в android/app/libs")
    }
}
