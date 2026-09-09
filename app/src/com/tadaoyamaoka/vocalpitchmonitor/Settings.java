package com.tadaoyamaoka.vocalpitchmonitor;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Application settings persisted in a single SharedPreferences file.
 *
 * Values and keys match the original VocalPitchMonitor app so that existing
 * preference files keep working. Added keys: tuning-config import memory
 * (config URI + display name + cached parsed payload).
 */
public class Settings {
    public static boolean AUTO_SCROLL_DEFAULT = true;
    public static int BOTTOM_CENT_DEFAULT = 2400;
    public static int BOTTOM_CENT_MAX = 7200;
    public static int BOTTOM_CENT_MIN = 0;
    public static int BPM_DEFAULT = 120;
    public static int BPM_MAX = 250;
    public static int BPM_MIN = 20;
    public static int CALIBRATION_DEFAULT = 440;
    public static int CALIBRATION_MAX = 450;
    public static int CALIBRATION_MIN = 430;
    public static int COLOR_1_DEFAULT = -8355712;
    public static int COLOR_2_DEFAULT = -12566464;
    public static int COLOR_3_DEFAULT = -12566464;
    public static int COLOR_4_DEFAULT = -12566464;
    public static int COLOR_5_DEFAULT = -12566464;
    public static int COLOR_6_DEFAULT = -12566464;
    public static int COLOR_7_DEFAULT = -12566464;
    public static int COLOR_CHROMATIC_DEFAULT = -12566464;
    public static int COLOR_METRONOME_DEFAULT = -16777088;
    public static int COLOR_PITCH_DEFAULT = -256;
    public static int COLOR_SEMITONE_DEFAULT = -14671840;
    public static int COLOR_TEMPO_DEFAULT = -12566464;
    public static boolean DISPLAY_BPM_DEFAULT = false;
    public static boolean DISPLAY_BUTTON_HOLD_DEFAULT = true;
    public static boolean DISPLAY_BUTTON_SCALE_DEFAULT = true;
    public static boolean DISPLAY_BUTTON_TEMPO_DEFAULT = true;
    public static boolean DISPLAY_HZ_DEFAULT = true;
    public static boolean DISPLAY_METRONOME_DEFAULT = false;
    // "Semitone" is not well defined for arbitrary tuning scales: the toggles
    // were removed from the settings UI and stay off for good.
    public static boolean DISPLAY_SEMITONE_DEFAULT = false;
    public static boolean DISPLAY_TUNER_DEFAULT = true;
    public static float HORIZONTAL_ZOOMING_DEFAULT = 1.0f;
    public static float HORIZONTAL_ZOOMING_MAX = 2.0f;
    public static float HORIZONTAL_ZOOMING_MIN = 1.0f;
    public static boolean INDICATE_SEMITONE_DEFAULT = false;
    public static String METER_DEFAULT = "4/4";
    public static String NOTE_NAME_DEFAULT = "english";
    public static String OCTAVE_NUMBER_DEFAULT = "A4";
    public static String SCALE_DEFAULT = "7ed2 on C";
    public static int SCROLL_SPEED_DEFAULT = 5;
    public static int SCROLL_SPEED_MAX = 10;
    public static int SCROLL_SPEED_MIN = 1;
    public static float THRESHOLD_DEFAULT = 2.0f;
    public static float THRESHOLD_MAX = 50.0f;
    public static float THRESHOLD_MIN = 0.0f;
    public static int TRANSPOSE_DEFAULT = 0;
    public static int TRANSPOSE_MAX = 11;
    public static int TRANSPOSE_MIN = -11;
    public static int TUNER_SMOOTH_DEFAULT = 3;
    public static int TUNER_SMOOTH_MAX = 5;
    public static int TUNER_SMOOTH_MIN = 1;
    public static int VERSION = 5;
    public static float VERTICAL_ZOOMING_DEFAULT = 1.0f;
    public static float VERTICAL_ZOOMING_MAX = 2.0f;
    public static float VERTICAL_ZOOMING_MIN = 0.5f;

    // tuning config import memory
    public static final String PREF_KEY_CONFIG_URI = "key_config_uri";
    public static final String PREF_KEY_CONFIG_NAME = "key_config_name";
    public static final String PREF_KEY_CONFIG_PAYLOAD = "key_config_payload";

    public static final String PREF_KEY_AUTO_SCROLL = "key_auto_scroll";
    public static final String PREF_KEY_BOTTOM_CENT = "key_bottom_cent";
    public static final String PREF_KEY_BPM = "key_bpm";
    public static final String PREF_KEY_CALIBRATION = "key_calibration";
    public static final String PREF_KEY_COLOR_1 = "key_color_1";
    public static final String PREF_KEY_COLOR_2 = "key_color_2";
    public static final String PREF_KEY_COLOR_3 = "key_color_3";
    public static final String PREF_KEY_COLOR_4 = "key_color_4";
    public static final String PREF_KEY_COLOR_5 = "key_color_5";
    public static final String PREF_KEY_COLOR_6 = "key_color_6";
    public static final String PREF_KEY_COLOR_7 = "key_color_7";
    public static final String PREF_KEY_COLOR_CHROMATIC = "key_color_chromatic";
    public static final String PREF_KEY_COLOR_METRONOME = "key_color_Metronome";
    public static final String PREF_KEY_COLOR_PITCH = "key_color_pitch";
    public static final String PREF_KEY_COLOR_SEMITONE = "key_color_semitone";
    public static final String PREF_KEY_COLOR_TEMPO = "key_color_tempo";
    public static final String PREF_KEY_DISPLAY_BPM = "key_display_bpm";
    public static final String PREF_KEY_DISPLAY_BUTTON_HOLD = "key_display_button_hold";
    public static final String PREF_KEY_DISPLAY_BUTTON_SCALE = "key_display_button_scale";
    public static final String PREF_KEY_DISPLAY_BUTTON_TEMPO = "key_display_button_tempo";
    public static final String PREF_KEY_DISPLAY_HZ = "key_display_hz";
    public static final String PREF_KEY_DISPLAY_METRONOME = "key_display_metronome";
    public static final String PREF_KEY_DISPLAY_SEMITONE = "key_display_semitone";
    public static final String PREF_KEY_DISPLAY_TUNER = "key_display_tuner";
    public static final String PREF_KEY_HORIZONTAL_ZOOMING = "key_horizontal_zooming";
    public static final String PREF_KEY_INDICATE_SEMITONE = "key_indicate_semitone";
    public static final String PREF_KEY_METER = "key_meter";
    public static final String PREF_KEY_NOTE_NAME = "key_note_name";
    public static final String PREF_KEY_OCTAVE_NUMBER = "key_octave_number";
    public static final String PREF_KEY_SCALE = "key_scale";
    public static final String PREF_KEY_SCROLL_SPEED = "key_scroll_speed";
    public static final String PREF_KEY_THRESHOLD = "key_threshold";
    public static final String PREF_KEY_TRANSPOSE = "key_transpose";
    public static final String PREF_KEY_TUNER_SMOOTH = "key_tuner_smooth";
    public static final String PREF_KEY_VERSION = "version";
    public static final String PREF_KEY_VERTICAL_ZOOMING = "key_vertical_zooming";

    private static final String PREF_FILE = "vocalpitchmonitor_settings";

    private SharedPreferences.Editor editor = null;
    private SharedPreferences pref;

    private SharedPreferences.Editor getEditor() {
        if (this.editor == null) {
            this.editor = this.pref.edit();
        }
        return this.editor;
    }

    public Settings(Context context) {
        this.pref = context.getSharedPreferences(PREF_FILE, Context.MODE_PRIVATE);
    }

    public void commit() {
        SharedPreferences.Editor editor = this.editor;
        if (editor != null) {
            editor.putInt(PREF_KEY_VERSION, VERSION);
            editor.commit();
        }
    }

    public void checkVersion() {
        if (this.pref.getInt(PREF_KEY_VERSION, 0) != VERSION) {
            SharedPreferences.Editor editor = getEditor();
            // Version 5 made the Hz display default-on: apply it once for
            // installs that predate the new default (fresh installs get the
            // same explicit value, which equals the new default anyway).
            editor.putBoolean(PREF_KEY_DISPLAY_HZ, true);
            editor.remove(PREF_KEY_VERSION);
            editor.remove(PREF_KEY_THRESHOLD);
            editor.commit();
        }
    }

    // --- tuning config import memory ---

    public String getConfigUri() {
        return this.pref.getString(PREF_KEY_CONFIG_URI, null);
    }

    public void setConfigUri(String uri) {
        getEditor().putString(PREF_KEY_CONFIG_URI, uri);
    }

    public String getConfigName() {
        return this.pref.getString(PREF_KEY_CONFIG_NAME, null);
    }

    public void setConfigName(String name) {
        getEditor().putString(PREF_KEY_CONFIG_NAME, name);
    }

    /** Cached serialized parsing result; survives file permission loss. */
    public String getConfigPayload() {
        return this.pref.getString(PREF_KEY_CONFIG_PAYLOAD, null);
    }

    public void setConfigPayload(String payload) {
        getEditor().putString(PREF_KEY_CONFIG_PAYLOAD, payload);
    }

    public void clearConfig() {
        SharedPreferences.Editor e = getEditor();
        e.remove(PREF_KEY_CONFIG_URI);
        e.remove(PREF_KEY_CONFIG_NAME);
        e.remove(PREF_KEY_CONFIG_PAYLOAD);
    }

    public float getThreshold() {
        float f = this.pref.getFloat(PREF_KEY_THRESHOLD, THRESHOLD_DEFAULT);
        return (f < THRESHOLD_MIN || f > THRESHOLD_MAX) ? THRESHOLD_DEFAULT : f;
    }

    public void setThreshold(float f) {
        getEditor().putFloat(PREF_KEY_THRESHOLD, f);
    }

    public float getHorizontalZooming() {
        float f = this.pref.getFloat(PREF_KEY_HORIZONTAL_ZOOMING, HORIZONTAL_ZOOMING_DEFAULT);
        return (f < HORIZONTAL_ZOOMING_MIN || f > HORIZONTAL_ZOOMING_MAX) ? HORIZONTAL_ZOOMING_DEFAULT : f;
    }

    public void setHorizontalZooming(float f) {
        getEditor().putFloat(PREF_KEY_HORIZONTAL_ZOOMING, f);
    }

    public float getVerticalZooming() {
        float f = this.pref.getFloat(PREF_KEY_VERTICAL_ZOOMING, VERTICAL_ZOOMING_DEFAULT);
        return (f < VERTICAL_ZOOMING_MIN || f > VERTICAL_ZOOMING_MAX) ? VERTICAL_ZOOMING_DEFAULT : f;
    }

    public void setVerticalZooming(float f) {
        getEditor().putFloat(PREF_KEY_VERTICAL_ZOOMING, f);
    }

    public int getBottomCent() {
        int i = this.pref.getInt(PREF_KEY_BOTTOM_CENT, BOTTOM_CENT_DEFAULT);
        return (i < BOTTOM_CENT_MIN || i > BOTTOM_CENT_MAX) ? BOTTOM_CENT_DEFAULT : i;
    }

    public void setBottomCent(int i) {
        getEditor().putInt(PREF_KEY_BOTTOM_CENT, i);
    }

    public boolean getIndicateSemitone() {
        return this.pref.getBoolean(PREF_KEY_INDICATE_SEMITONE, INDICATE_SEMITONE_DEFAULT);
    }

    public void setIndicateSemitone(boolean z) {
        getEditor().putBoolean(PREF_KEY_INDICATE_SEMITONE, z);
    }

    public boolean getDisplaySemitone() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_SEMITONE, DISPLAY_SEMITONE_DEFAULT);
    }

    public void setDisplaySemitone(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_SEMITONE, z);
    }

    public String getOctaveNumber() {
        return this.pref.getString(PREF_KEY_OCTAVE_NUMBER, OCTAVE_NUMBER_DEFAULT);
    }

    public void setOctaveNumber(String str) {
        getEditor().putString(PREF_KEY_OCTAVE_NUMBER, str);
    }

    public int getCalibration() {
        int i = this.pref.getInt(PREF_KEY_CALIBRATION, CALIBRATION_DEFAULT);
        return (i < CALIBRATION_MIN || i > CALIBRATION_MAX) ? CALIBRATION_DEFAULT : i;
    }

    public void setCalibration(int i) {
        getEditor().putInt(PREF_KEY_CALIBRATION, i);
    }

    public int getTranspose() {
        int i = this.pref.getInt(PREF_KEY_TRANSPOSE, TRANSPOSE_DEFAULT);
        return (i < TRANSPOSE_MIN || i > TRANSPOSE_MAX) ? TRANSPOSE_DEFAULT : i;
    }

    public void setTranspose(int i) {
        getEditor().putInt(PREF_KEY_TRANSPOSE, i);
    }

    public boolean getAutoScroll() {
        return this.pref.getBoolean(PREF_KEY_AUTO_SCROLL, AUTO_SCROLL_DEFAULT);
    }

    public void setAutoScroll(boolean z) {
        getEditor().putBoolean(PREF_KEY_AUTO_SCROLL, z);
    }

    public int getScrollSpeed() {
        int i = this.pref.getInt(PREF_KEY_SCROLL_SPEED, SCROLL_SPEED_DEFAULT);
        return (i < SCROLL_SPEED_MIN || i > SCROLL_SPEED_MAX) ? SCROLL_SPEED_DEFAULT : i;
    }

    public void setScrollSpeed(int i) {
        getEditor().putInt(PREF_KEY_SCROLL_SPEED, i);
    }

    public boolean getDisplayHz() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_HZ, DISPLAY_HZ_DEFAULT);
    }

    public void setDisplayHz(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_HZ, z);
    }

    public boolean getDisplayTuner() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_TUNER, DISPLAY_TUNER_DEFAULT);
    }

    public void setDisplayTuner(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_TUNER, z);
    }

    public int getTunerSmooth() {
        int i = this.pref.getInt(PREF_KEY_TUNER_SMOOTH, TUNER_SMOOTH_DEFAULT);
        return (i < TUNER_SMOOTH_MIN || i > TUNER_SMOOTH_MAX) ? TUNER_SMOOTH_DEFAULT : i;
    }

    public void setTunerSmooth(int i) {
        getEditor().putInt(PREF_KEY_TUNER_SMOOTH, i);
    }

    public String getNoteName() {
        return this.pref.getString(PREF_KEY_NOTE_NAME, NOTE_NAME_DEFAULT);
    }

    public void setNoteName(String str) {
        getEditor().putString(PREF_KEY_NOTE_NAME, str);
    }

    public boolean getDisplayBpm() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_BPM, DISPLAY_BPM_DEFAULT);
    }

    public void setDisplayBpm(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_BPM, z);
    }

    public boolean getDisplayMetronome() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_METRONOME, DISPLAY_METRONOME_DEFAULT);
    }

    public void setDisplayMetronome(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_METRONOME, z);
    }

    public int getBpm() {
        int i = this.pref.getInt(PREF_KEY_BPM, BPM_DEFAULT);
        return (i < BPM_MIN || i > BPM_MAX) ? BPM_DEFAULT : i;
    }

    public void setBpm(int i) {
        getEditor().putInt(PREF_KEY_BPM, i);
    }

    public String getMeter() {
        return this.pref.getString(PREF_KEY_METER, METER_DEFAULT);
    }

    public void setMeter(String str) {
        getEditor().putString(PREF_KEY_METER, str);
    }

    public boolean getDisplayButtonHold() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_BUTTON_HOLD, DISPLAY_BUTTON_HOLD_DEFAULT);
    }

    public void setDisplayButtonHold(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_BUTTON_HOLD, z);
    }

    public boolean getDisplayButtonScale() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_BUTTON_SCALE, DISPLAY_BUTTON_SCALE_DEFAULT);
    }

    public void setDisplayButtonScale(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_BUTTON_SCALE, z);
    }

    public boolean getDisplayButtonTempo() {
        return this.pref.getBoolean(PREF_KEY_DISPLAY_BUTTON_TEMPO, DISPLAY_BUTTON_TEMPO_DEFAULT);
    }

    public void setDisplayButtonTempo(boolean z) {
        getEditor().putBoolean(PREF_KEY_DISPLAY_BUTTON_TEMPO, z);
    }

    public String getScale() {
        return this.pref.getString(PREF_KEY_SCALE, SCALE_DEFAULT);
    }

    public void setScale(String str) {
        getEditor().putString(PREF_KEY_SCALE, str);
    }

    public int getColorPitch() {
        return this.pref.getInt(PREF_KEY_COLOR_PITCH, COLOR_PITCH_DEFAULT);
    }

    public void setColorPitch(int i) {
        getEditor().putInt(PREF_KEY_COLOR_PITCH, i);
    }

    public int getColorTempo() {
        return this.pref.getInt(PREF_KEY_COLOR_TEMPO, COLOR_TEMPO_DEFAULT);
    }

    public void setColorTempo(int i) {
        getEditor().putInt(PREF_KEY_COLOR_TEMPO, i);
    }

    public int getColorMetronome() {
        return this.pref.getInt(PREF_KEY_COLOR_METRONOME, COLOR_METRONOME_DEFAULT);
    }

    public void setColorMetronome(int i) {
        getEditor().putInt(PREF_KEY_COLOR_METRONOME, i);
    }

    public int getColor1() {
        return this.pref.getInt(PREF_KEY_COLOR_1, COLOR_1_DEFAULT);
    }

    public void setColor1(int i) {
        getEditor().putInt(PREF_KEY_COLOR_1, i);
    }

    public int getColor2() {
        return this.pref.getInt(PREF_KEY_COLOR_2, COLOR_2_DEFAULT);
    }

    public void setColor2(int i) {
        getEditor().putInt(PREF_KEY_COLOR_2, i);
    }

    public int getColor3() {
        return this.pref.getInt(PREF_KEY_COLOR_3, COLOR_3_DEFAULT);
    }

    public void setColor3(int i) {
        getEditor().putInt(PREF_KEY_COLOR_3, i);
    }

    public int getColor4() {
        return this.pref.getInt(PREF_KEY_COLOR_4, COLOR_4_DEFAULT);
    }

    public void setColor4(int i) {
        getEditor().putInt(PREF_KEY_COLOR_4, i);
    }

    public int getColor5() {
        return this.pref.getInt(PREF_KEY_COLOR_5, COLOR_5_DEFAULT);
    }

    public void setColor5(int i) {
        getEditor().putInt(PREF_KEY_COLOR_5, i);
    }

    public int getColor6() {
        return this.pref.getInt(PREF_KEY_COLOR_6, COLOR_6_DEFAULT);
    }

    public void setColor6(int i) {
        getEditor().putInt(PREF_KEY_COLOR_6, i);
    }

    public int getColor7() {
        return this.pref.getInt(PREF_KEY_COLOR_7, COLOR_7_DEFAULT);
    }

    public void setColor7(int i) {
        getEditor().putInt(PREF_KEY_COLOR_7, i);
    }

    public int getColorSemitone() {
        return this.pref.getInt(PREF_KEY_COLOR_SEMITONE, COLOR_SEMITONE_DEFAULT);
    }

    public void setColorSemitone(int i) {
        getEditor().putInt(PREF_KEY_COLOR_SEMITONE, i);
    }

    public int getColorChromatic(int i) {
        return this.pref.getInt(PREF_KEY_COLOR_CHROMATIC + i, COLOR_CHROMATIC_DEFAULT);
    }

    public void setColorChromatic(int i, int i2) {
        getEditor().putInt(PREF_KEY_COLOR_CHROMATIC + i, i2);
    }
}
