package com.appstack.attribution

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.moshi.MoshiConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.Headers
import retrofit2.http.POST

/** Retrofit-powered implementation of [NetworkClient]. */
class RetrofitClient(
    baseUrl: String,
    private val apiKey: String,
    okHttpClient: OkHttpClient = defaultOkHttpClient(),
) : NetworkClient {

    private val service: EndpointService

    init {
        val moshi = com.squareup.moshi.Moshi.Builder()
            .addLast(com.squareup.moshi.kotlin.reflect.KotlinJsonAdapterFactory())
            .build()
            
        val retrofit = Retrofit.Builder()
            .baseUrl(baseUrl)
            .client(okHttpClient)
            .addConverterFactory(MoshiConverterFactory.create(moshi))
            .build()
        service = retrofit.create(EndpointService::class.java)
    }

    /**
     * CRITICAL WORKAROUND FOR REFLECTION-BASED INSTANTIATION
     * 
     * The core SDK module uses reflection to dynamically load this RetrofitClient class:
     * ```kotlin
     * val cls = Class.forName("com.appstack.attribution.network.RetrofitClient")
     * val ctor = cls.constructors.firstOrNull { it.parameterTypes.size == 2 }
     * ctor.newInstance(config.endpointBaseUrl, config.apiKey)
     * ```
     * 
     * GOTCHA: When using reflection to find constructors by parameter count, we need an explicit
     * constructor that matches exactly what we're looking for. The primary constructor above has
     * 3 parameters, but the reflection code specifically looks for a 2-parameter constructor.
     * 
     * Without this explicit 2-parameter constructor, the reflection lookup fails and the SDK
     * silently falls back to a no-op NetworkClient stub, causing all HTTP requests to be dropped.
     * 
     * SOLUTION: This secondary constructor explicitly exposes a clean 2-parameter
     * (String, String) constructor that Java reflection can find and invoke successfully.
     * 
     * DO NOT REMOVE THIS CONSTRUCTOR - it's required for the SDK to work in production.
     */
    constructor(baseUrl: String, apiKey: String) : this(baseUrl, apiKey, defaultOkHttpClient())

    override suspend fun postEvents(payload: EventsBatchPayload) {
        withContext(Dispatchers.IO) {
            val response = service.postEvents(apiKey, payload)
            if (!response.isSuccessful) {
                when (response.code()) {
                    401, 403 -> throw AuthenticationException(response.code())
                    else -> throw HttpException(response.code())
                }
            }
        }
    }

    override suspend fun fetchRemoteConfig(): RemoteConfig {
        return withContext(Dispatchers.IO) {
            val response = service.getConfig(apiKey)
            if (!response.isSuccessful) {
                when (response.code()) {
                    401, 403 -> throw AuthenticationException(response.code())
                    else -> throw HttpException(response.code())
                }
            }
            response.body() ?: throw HttpException(response.code())
        }
    }

    // -------------------------------------------------------
    // Retrofit definition
    // -------------------------------------------------------

    private interface EndpointService {
        @POST("event")
        suspend fun postEvents(
            @Header("X-Api-Key") apiKey: String,
            @Body payload: EventsBatchPayload,
        ): retrofit2.Response<Unit>

        @GET("config")
        @Headers("Accept: application/json")
        suspend fun getConfig(
            @Header("X-Api-Key") apiKey: String,
        ): retrofit2.Response<RemoteConfig>
    }

    companion object {
        private fun defaultOkHttpClient(): OkHttpClient {
            val logger = HttpLoggingInterceptor().apply { setLevel(HttpLoggingInterceptor.Level.BASIC) }
            val headerAuthInterceptor = Interceptor { chain ->
                val original = chain.request()
                // Leave header injection to Retrofit call-level for per-request dynamic secret
                chain.proceed(original)
            }
            return OkHttpClient.Builder()
                .addInterceptor(logger)
                .addInterceptor(headerAuthInterceptor)
                .build()
        }
    }
}

/**
 * Exception thrown when retrofit Response is not successful.
 */
class HttpException(val code: Int) : RuntimeException("HTTP $code error from backend")

/**
 * Exception thrown when API key authentication fails (401/403).
 * This indicates a permanent configuration error that requires intervention.
 */
class AuthenticationException(val code: Int) : RuntimeException("Authentication failed - invalid API key (HTTP $code)") 