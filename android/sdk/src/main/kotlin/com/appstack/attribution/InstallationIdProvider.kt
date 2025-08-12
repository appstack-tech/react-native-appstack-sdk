package com.appstack.attribution

/**
 * Generates an installation-scoped UUID on first launch and persists it via [StorageProvider].
 * The plain UUID string is returned directly without further hashing.
 */
class InstallationIdProviderImpl(
    private val storage: StorageProvider,
) : InstallationIdProvider {

    /**
     * Returns the stable installation ID (UUID). If it does not exist yet, a new UUID is generated
     * and persisted for future calls.
     */
    override fun getInstallationId(): String {
        return storage.getString(KEY_RAW_ID) ?: generateAndPersist()
    }

    private fun generateAndPersist(): String {
        val uuid = java.util.UUID.randomUUID().toString()
        storage.putString(KEY_RAW_ID, uuid)
        Logger.d(TAG, "Generated new installation ID: $uuid")
        return uuid
    }

    companion object {
        private const val TAG = "InstallationIdProvider"
        private const val KEY_RAW_ID = Constants.KEY_RAW_ID
    }
} 