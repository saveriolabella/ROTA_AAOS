package com.harmonyhoney.audiofocus;

import android.content.Context;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

public class RotaAudioFocusPlugin extends GodotPlugin {
    private static final String PLUGIN_NAME = "RotaAudioFocusPlugin";

    private AudioManager audioManager;
    private AudioFocusRequest audioFocusRequest;
    private AudioManager.OnAudioFocusChangeListener audioFocusChangeListener;

    public RotaAudioFocusPlugin(Godot godot) {
        super(godot);

        audioFocusChangeListener =
                new AudioManager.OnAudioFocusChangeListener() {
                    @Override
                    public void onAudioFocusChange(int focusChange) {
                        // Audio focus changes can be handled here if needed.
                        //
                        // Values include:
                        // AudioManager.AUDIOFOCUS_GAIN
                        // AudioManager.AUDIOFOCUS_LOSS
                        // AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
                        // AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK
                        emitSignal("focus_changed", focusChange);
                    }
                };
    }

    @Override
    public String getPluginName() {
        return PLUGIN_NAME;
    }

    private AudioManager getAudioManager() {
        if (audioManager == null && getActivity() != null) {
            audioManager =
                    (AudioManager)
                            getActivity().getSystemService(Context.AUDIO_SERVICE);
        }

        return audioManager;
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        // Signal emits standard int status:
        //  1  = AUDIOFOCUS_GAIN
        // -1  = AUDIOFOCUS_LOSS (Permanent)
        // -2  = AUDIOFOCUS_LOSS_TRANSIENT (Temporary, e.g., phone call)
        // -3  = AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK (Temporary, e.g., notification)
        signals.add(new SignalInfo("focus_changed", Integer.class));
        return signals;
    }

    @UsedByGodot
    public boolean request_audio_focus() {
        AudioManager manager = getAudioManager();

        if (manager == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            AudioAttributes audioAttributes =
                    new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_GAME)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build();

            audioFocusRequest =
                    new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                            .setAudioAttributes(audioAttributes)
                            .setAcceptsDelayedFocusGain(false)
                            .setOnAudioFocusChangeListener(audioFocusChangeListener)
                            .build();

            int result = manager.requestAudioFocus(audioFocusRequest);

            return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
        }

        @SuppressWarnings("deprecation")
        int result =
                manager.requestAudioFocus(
                        audioFocusChangeListener,
                        AudioManager.STREAM_MUSIC,
                        AudioManager.AUDIOFOCUS_GAIN);

        return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
    }

    @UsedByGodot
    public boolean abandon_audio_focus() {
        AudioManager manager = getAudioManager();

        if (manager == null) {
            return false;
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (audioFocusRequest == null) {
                return true;
            }

            int result = manager.abandonAudioFocusRequest(audioFocusRequest);
            audioFocusRequest = null;

            return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
        }

        @SuppressWarnings("deprecation")
        int result = manager.abandonAudioFocus(audioFocusChangeListener);

        return result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED;
    }
}
