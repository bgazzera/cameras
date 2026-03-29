package com.bgazzera.hikvisionmobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import java.net.URLEncoder

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    HikvisionMobileScreen()
                }
            }
        }
    }
}

data class NvrConfiguration(
    val host: String = "",
    val username: String = "",
    val rtspPort: Int = 554,
    val selectedChannelId: String = "101",
    val doorbellHost: String = "",
    val doorbellRtspPort: Int = 554,
    val doorbellHdChannelId: String = "101",
    val doorbellSdChannelId: String = "102",
    val preferHd: Boolean = true,
)

val NvrConfiguration.activeDoorbellChannelId: String
    get() {
        val preferred = if (preferHd) doorbellHdChannelId.trim() else doorbellSdChannelId.trim()
        return if (preferred.isNotEmpty()) preferred else if (preferHd) "101" else "102"
    }

object RtspUrlBuilder {
    fun build(host: String, username: String, password: String, rtspPort: Int, channelId: String): String {
        require(host.isNotBlank()) { "Enter the NVR host or IP address." }
        require(username.isNotBlank()) { "Enter the NVR username." }
        require(password.isNotBlank()) { "Enter the NVR password." }
        require(channelId.isNotBlank()) { "Choose or enter a channel ID." }

        val normalizedChannelId = normalizeChannelId(channelId.trim())
        val encodedUser = encodeUrlComponent(username)
        val encodedPassword = encodeUrlComponent(password.trim())
        val encodedChannel = encodeUrlComponent(normalizedChannelId)
        return "rtsp://$encodedUser:$encodedPassword@$host:$rtspPort/Streaming/Channels/$encodedChannel?transportmode=unicast"
    }

    private fun normalizeChannelId(value: String): String {
        if (value.length >= 3) {
            return value
        }

        val numericValue = value.toIntOrNull() ?: return value
        if (numericValue == 0) {
            return "001"
        }

        return if (numericValue < 100) "$numericValue${if (value.length == 1) "01" else "01"}" else value
    }

    private fun encodeUrlComponent(value: String): String {
        return URLEncoder.encode(value, "UTF-8").replace("+", "%20")
    }
}

class MainViewModel : ViewModel() {
    var configuration by mutableStateOf(NvrConfiguration())
        private set

    var password by mutableStateOf("")
        private set

    var currentStreamUrl by mutableStateOf<String?>(null)
        private set

    var isMuted by mutableStateOf(false)
        private set

    var isShowingDoorbellStream by mutableStateOf(false)
        private set

    var errorMessage by mutableStateOf("")
        private set

    fun updateConfiguration(transform: (NvrConfiguration) -> NvrConfiguration) {
        configuration = transform(configuration)
    }

    fun updatePassword(value: String) {
        password = value
    }

    fun connectSelectedChannel() {
        runCatching {
            currentStreamUrl = RtspUrlBuilder.build(
                host = configuration.host.trim(),
                username = configuration.username.trim(),
                password = password,
                rtspPort = configuration.rtspPort,
                channelId = configuration.selectedChannelId.trim(),
            )
            isShowingDoorbellStream = false
            errorMessage = ""
        }.onFailure {
            errorMessage = it.message.orEmpty()
        }
    }

    fun connectDoorbell() {
        runCatching {
            currentStreamUrl = RtspUrlBuilder.build(
                host = configuration.doorbellHost.trim(),
                username = configuration.username.trim(),
                password = password,
                rtspPort = configuration.doorbellRtspPort,
                channelId = configuration.activeDoorbellChannelId,
            )
            isShowingDoorbellStream = true
            errorMessage = ""
        }.onFailure {
            errorMessage = it.message.orEmpty()
        }
    }

    fun toggleMute() {
        isMuted = !isMuted
    }

    fun toggleDoorbellStreamMode() {
        configuration = configuration.copy(preferHd = !configuration.preferHd)
        if (isShowingDoorbellStream) {
            connectDoorbell()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HikvisionMobileScreen(viewModel: MainViewModel = viewModel()) {
    val context = LocalContext.current
    val player = remember(context) {
        ExoPlayer.Builder(context).build().apply {
            playWhenReady = true
        }
    }

    DisposableEffect(player) {
        onDispose {
            player.release()
        }
    }

    val currentStreamUrl = viewModel.currentStreamUrl
    DisposableEffect(currentStreamUrl, viewModel.isMuted) {
        if (currentStreamUrl != null) {
            player.setMediaItem(MediaItem.fromUri(currentStreamUrl))
            player.prepare()
        } else {
            player.stop()
            player.clearMediaItems()
        }
        player.volume = if (viewModel.isMuted) 0f else 1f
        onDispose { }
    }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(title = { Text("Hikvision Mobile") })
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            AndroidView(
                factory = { ctx ->
                    PlayerView(ctx).apply {
                        useController = true
                        this.player = player
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .size(height = 240.dp, width = 1.dp),
                update = { it.player = player },
            )

            Text(
                text = currentStreamUrl ?: "No stream connected yet.",
                style = MaterialTheme.typography.bodySmall,
            )

            if (viewModel.errorMessage.isNotBlank()) {
                Text(
                    text = viewModel.errorMessage,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            SettingsFields(viewModel)

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                Button(onClick = viewModel::connectSelectedChannel, modifier = Modifier.weight(1f)) {
                    Text("Connect")
                }
                Button(onClick = viewModel::connectDoorbell, modifier = Modifier.weight(1f)) {
                    Text("Portero")
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                Button(onClick = viewModel::toggleDoorbellStreamMode, modifier = Modifier.weight(1f)) {
                    Text(if (viewModel.configuration.preferHd) "HD" else "SD")
                }
                Button(onClick = viewModel::toggleMute, modifier = Modifier.weight(1f)) {
                    Text(if (viewModel.isMuted) "Unmute" else "Mute")
                }
            }
        }
    }
}

@Composable
private fun SettingsFields(viewModel: MainViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedTextField(
            value = viewModel.configuration.host,
            onValueChange = { viewModel.updateConfiguration { current -> current.copy(host = it) } },
            label = { Text("NVR Host") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = viewModel.configuration.username,
            onValueChange = { viewModel.updateConfiguration { current -> current.copy(username = it) } },
            label = { Text("Username") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = viewModel.password,
            onValueChange = viewModel::updatePassword,
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = viewModel.configuration.selectedChannelId,
            onValueChange = { viewModel.updateConfiguration { current -> current.copy(selectedChannelId = it) } },
            label = { Text("Channel ID") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = viewModel.configuration.doorbellHost,
            onValueChange = { viewModel.updateConfiguration { current -> current.copy(doorbellHost = it) } },
            label = { Text("Doorbell Host") },
            modifier = Modifier.fillMaxWidth(),
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Prefer HD for doorbell")
            Switch(
                checked = viewModel.configuration.preferHd,
                onCheckedChange = { checked ->
                    viewModel.updateConfiguration { current -> current.copy(preferHd = checked) }
                },
            )
        }
    }
}
