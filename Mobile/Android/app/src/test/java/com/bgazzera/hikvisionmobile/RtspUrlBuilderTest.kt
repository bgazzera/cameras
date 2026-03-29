package com.bgazzera.hikvisionmobile

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class RtspUrlBuilderTest {
    @Test
    fun normalizesShortChannelIds() {
        val result = RtspUrlBuilder.build(
            host = "192.168.1.10",
            username = "admin",
            password = "secret",
            rtspPort = 554,
            channelId = "1",
        )

        assertThat(result)
            .isEqualTo("rtsp://admin:secret@192.168.1.10:554/Streaming/Channels/101?transportmode=unicast")
    }
}