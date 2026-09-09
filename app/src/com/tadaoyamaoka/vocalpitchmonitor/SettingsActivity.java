package com.tadaoyamaoka.vocalpitchmonitor;

import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.ExpandableListView;
import android.widget.ImageButton;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.SimpleExpandableListAdapter;
import android.widget.Spinner;
import android.widget.TextView;
import android.app.ActionBar;
import android.app.Activity;
import java.util.ArrayList;
import java.util.HashMap;

public class SettingsActivity extends Activity implements View.OnClickListener {
    Settings settings = null;

    /* JADX INFO: Access modifiers changed from: protected */
    @Override // androidx.fragment.app.FragmentActivity, androidx.activity.ComponentActivity, androidx.core.app.ComponentActivity, android.app.Activity
    public void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        setContentView(R.layout.layout_settings);
        ActionBar supportActionBar = getActionBar();
        if (supportActionBar != null) {
            supportActionBar.setDisplayHomeAsUpEnabled(true);
        }
        Settings settings = new Settings(this);
        this.settings = settings;
        float threshold = settings.getThreshold();
        SeekBar seekBar = (SeekBar) findViewById(R.id.seekBarThreshold);
        seekBar.setMax(1000);
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.1
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar2) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar2) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar2, int i, boolean z) {
                ((TextView) SettingsActivity.this.findViewById(R.id.textViewThreshold)).setText(String.format("%.2f", Float.valueOf(((seekBar2.getProgress() / seekBar2.getMax()) * (Settings.THRESHOLD_MAX - Settings.THRESHOLD_MIN)) + Settings.THRESHOLD_MIN)));
            }
        });
        seekBar.setProgress((int) (((threshold - Settings.THRESHOLD_MIN) / (Settings.THRESHOLD_MAX - Settings.THRESHOLD_MIN)) * seekBar.getMax()));
        float horizontalZooming = this.settings.getHorizontalZooming();
        SeekBar seekBar2 = (SeekBar) findViewById(R.id.seekBarHorizontalZooming);
        seekBar2.setMax(1000);
        seekBar2.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.2
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar3) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar3) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar3, int i, boolean z) {
                ((TextView) SettingsActivity.this.findViewById(R.id.textViewHorizontalZooming)).setText(String.format("%.2f", Float.valueOf(((seekBar3.getProgress() / seekBar3.getMax()) * (Settings.HORIZONTAL_ZOOMING_MAX - Settings.HORIZONTAL_ZOOMING_MIN)) + Settings.HORIZONTAL_ZOOMING_MIN)));
            }
        });
        seekBar2.setProgress((int) (((horizontalZooming - Settings.HORIZONTAL_ZOOMING_MIN) / (Settings.HORIZONTAL_ZOOMING_MAX - Settings.HORIZONTAL_ZOOMING_MIN)) * seekBar2.getMax()));
        float verticalZooming = this.settings.getVerticalZooming();
        SeekBar seekBar3 = (SeekBar) findViewById(R.id.seekBarVerticalZooming);
        seekBar3.setMax(1000);
        seekBar3.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.3
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar4, int i, boolean z) {
                ((TextView) SettingsActivity.this.findViewById(R.id.textViewVerticalZooming)).setText(String.format("%.2f", Float.valueOf(((seekBar4.getProgress() / seekBar4.getMax()) * (Settings.VERTICAL_ZOOMING_MAX - Settings.VERTICAL_ZOOMING_MIN)) + Settings.VERTICAL_ZOOMING_MIN)));
            }
        });
        seekBar3.setProgress((int) (((verticalZooming - Settings.VERTICAL_ZOOMING_MIN) / (Settings.VERTICAL_ZOOMING_MAX - Settings.VERTICAL_ZOOMING_MIN)) * seekBar3.getMax()));
        ((CheckBox) findViewById(R.id.checkBoxAutoScroll)).setChecked(this.settings.getAutoScroll());
        int scrollSpeed = this.settings.getScrollSpeed();
        SeekBar seekBar6 = (SeekBar) findViewById(R.id.seekBarScrollSpeed);
        seekBar6.setMax(Settings.SCROLL_SPEED_MAX - Settings.SCROLL_SPEED_MIN);
        seekBar6.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.8
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar7) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar7) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar7, int i, boolean z) {
                ((TextView) SettingsActivity.this.findViewById(R.id.textViewScrollSpeedVal)).setText(String.valueOf(seekBar7.getProgress() + Settings.SCROLL_SPEED_MIN));
            }
        });
        seekBar6.setProgress(scrollSpeed - Settings.SCROLL_SPEED_MIN);
        ((CheckBox) findViewById(R.id.checkBoxDisplayHz)).setChecked(this.settings.getDisplayHz());
        ((CheckBox) findViewById(R.id.checkBoxDisplayTuner)).setChecked(this.settings.getDisplayTuner());
        int tunerSmooth = this.settings.getTunerSmooth();
        SeekBar seekBar7 = (SeekBar) findViewById(R.id.seekBarTunerSmooth);
        seekBar7.setMax(Settings.TUNER_SMOOTH_MAX - Settings.TUNER_SMOOTH_MIN);
        seekBar7.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.9
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar8) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar8) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar8, int i, boolean z) {
                ((TextView) SettingsActivity.this.findViewById(R.id.textViewTunerSmoothVal)).setText(String.valueOf(seekBar8.getProgress() + Settings.TUNER_SMOOTH_MIN));
            }
        });
        seekBar7.setProgress(tunerSmooth - Settings.TUNER_SMOOTH_MIN);
        ((CheckBox) findViewById(R.id.checkBoxDisplayBpm)).setChecked(this.settings.getDisplayBpm());
        ((CheckBox) findViewById(R.id.checkBoxDisplayMetronome)).setChecked(this.settings.getDisplayMetronome());
        int bpm = this.settings.getBpm();
        final SeekBar seekBar8 = (SeekBar) findViewById(R.id.seekBarBpm);
        seekBar8.setMax(Settings.BPM_MAX - Settings.BPM_MIN);
        seekBar8.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.10
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar9) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar9) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar9, int i, boolean z) {
                ((TextView) SettingsActivity.this.findViewById(R.id.textViewBpmVal)).setText(String.valueOf(seekBar9.getProgress() + Settings.BPM_MIN));
            }
        });
        seekBar8.setProgress(bpm - Settings.BPM_MIN);
        findViewById(R.id.buttonBPMDown).setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.11
            @Override // android.view.View.OnClickListener
            public void onClick(View view) {
                SeekBar seekBar9 = seekBar8;
                seekBar9.setProgress(seekBar9.getProgress() - 1);
            }
        });
        findViewById(R.id.buttonBPMUp).setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.SettingsActivity.12
            @Override // android.view.View.OnClickListener
            public void onClick(View view) {
                SeekBar seekBar9 = seekBar8;
                seekBar9.setProgress(seekBar9.getProgress() + 1);
            }
        });
        String meter = this.settings.getMeter();
        RadioGroup radioGroup4 = (RadioGroup) findViewById(R.id.radioGroupMeter);
        if ("4/4".equals(meter)) {
            radioGroup4.check(R.id.radioButtonMeter4);
        } else if ("3/4".equals(meter)) {
            radioGroup4.check(R.id.radioButtonMeter3);
        } else {
            radioGroup4.check(R.id.radioButtonMeterNone);
        }
        ((CheckBox) findViewById(R.id.checkBoxDisplayButtonHold)).setChecked(this.settings.getDisplayButtonHold());
        ((CheckBox) findViewById(R.id.checkBoxDisplayButtonScale)).setChecked(this.settings.getDisplayButtonScale());
        ((CheckBox) findViewById(R.id.checkBoxDisplayButtonTempo)).setChecked(this.settings.getDisplayButtonTempo());
    }

    private void setButtonColor(int i, int i2) {
        ((ImageButton) findViewById(i)).setImageDrawable(new ColorDrawable(i2));
    }

    @Override // android.app.Activity
    public void finish() {
        SeekBar seekBar = (SeekBar) findViewById(R.id.seekBarThreshold);
        this.settings.setThreshold(((seekBar.getProgress() / seekBar.getMax()) * (Settings.THRESHOLD_MAX - Settings.THRESHOLD_MIN)) + Settings.THRESHOLD_MIN);
        SeekBar seekBar2 = (SeekBar) findViewById(R.id.seekBarHorizontalZooming);
        this.settings.setHorizontalZooming(((seekBar2.getProgress() / seekBar2.getMax()) * (Settings.HORIZONTAL_ZOOMING_MAX - Settings.HORIZONTAL_ZOOMING_MIN)) + Settings.HORIZONTAL_ZOOMING_MIN);
        SeekBar seekBar3 = (SeekBar) findViewById(R.id.seekBarVerticalZooming);
        this.settings.setVerticalZooming(((seekBar3.getProgress() / seekBar3.getMax()) * (Settings.VERTICAL_ZOOMING_MAX - Settings.VERTICAL_ZOOMING_MIN)) + Settings.VERTICAL_ZOOMING_MIN);
        this.settings.setAutoScroll(((CheckBox) findViewById(R.id.checkBoxAutoScroll)).isChecked());
        this.settings.setScrollSpeed(((SeekBar) findViewById(R.id.seekBarScrollSpeed)).getProgress() + Settings.SCROLL_SPEED_MIN);
        this.settings.setDisplayHz(((CheckBox) findViewById(R.id.checkBoxDisplayHz)).isChecked());
        this.settings.setDisplayTuner(((CheckBox) findViewById(R.id.checkBoxDisplayTuner)).isChecked());
        this.settings.setTunerSmooth(((SeekBar) findViewById(R.id.seekBarTunerSmooth)).getProgress() + Settings.TUNER_SMOOTH_MIN);
        this.settings.setDisplayBpm(((CheckBox) findViewById(R.id.checkBoxDisplayBpm)).isChecked());
        this.settings.setDisplayMetronome(((CheckBox) findViewById(R.id.checkBoxDisplayMetronome)).isChecked());
        this.settings.setBpm(((SeekBar) findViewById(R.id.seekBarBpm)).getProgress() + Settings.BPM_MIN);
        RadioGroup radioGroup = (RadioGroup) findViewById(R.id.radioGroupMeter);
        if (radioGroup.getCheckedRadioButtonId() == R.id.radioButtonMeter4) {
            this.settings.setMeter("4/4");
        } else if (radioGroup.getCheckedRadioButtonId() == R.id.radioButtonMeter3) {
            this.settings.setMeter("3/4");
        } else {
            this.settings.setMeter("None");
        }
        this.settings.setDisplayButtonHold(((CheckBox) findViewById(R.id.checkBoxDisplayButtonHold)).isChecked());
        this.settings.setDisplayButtonScale(((CheckBox) findViewById(R.id.checkBoxDisplayButtonScale)).isChecked());
        this.settings.setDisplayButtonTempo(((CheckBox) findViewById(R.id.checkBoxDisplayButtonTempo)).isChecked());
        this.settings.setColorPitch(getButtonColor(R.id.buttonColorPitch));
        this.settings.setColorTempo(getButtonColor(R.id.buttonColorTempo));
        this.settings.setColorMetronome(getButtonColor(R.id.buttonColorMetronome));
        this.settings.commit();
        super.finish();
    }

    private int getButtonColor(int i) {
        return ColorPopupWindow.getColor((ColorDrawable) ((ImageButton) findViewById(i)).getDrawable());
    }

    @Override // android.app.Activity
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_settings, menu);
        return true;
    }

    @Override // android.app.Activity
    public boolean onOptionsItemSelected(MenuItem menuItem) {
        int itemId = menuItem.getItemId();
        if (itemId == 16908332) {
            finish();
            return true;
        } else if (itemId != R.id.action_default) {
            return super.onOptionsItemSelected(menuItem);
        } else {
            float f = Settings.THRESHOLD_DEFAULT;
            SeekBar seekBar = (SeekBar) findViewById(R.id.seekBarThreshold);
            seekBar.setProgress((int) (((f - Settings.THRESHOLD_MIN) / (Settings.THRESHOLD_MAX - Settings.THRESHOLD_MIN)) * seekBar.getMax()));
            float f2 = Settings.HORIZONTAL_ZOOMING_DEFAULT;
            SeekBar seekBar2 = (SeekBar) findViewById(R.id.seekBarHorizontalZooming);
            seekBar2.setProgress((int) (((f2 - Settings.HORIZONTAL_ZOOMING_MIN) / (Settings.HORIZONTAL_ZOOMING_MAX - Settings.HORIZONTAL_ZOOMING_MIN)) * seekBar2.getMax()));
            float f3 = Settings.VERTICAL_ZOOMING_DEFAULT;
            SeekBar seekBar3 = (SeekBar) findViewById(R.id.seekBarVerticalZooming);
            seekBar3.setProgress((int) (((f3 - Settings.VERTICAL_ZOOMING_MIN) / (Settings.VERTICAL_ZOOMING_MAX - Settings.VERTICAL_ZOOMING_MIN)) * seekBar3.getMax()));
            ((CheckBox) findViewById(R.id.checkBoxAutoScroll)).setChecked(Settings.AUTO_SCROLL_DEFAULT);
            ((SeekBar) findViewById(R.id.seekBarScrollSpeed)).setProgress(Settings.SCROLL_SPEED_DEFAULT - Settings.SCROLL_SPEED_MIN);
            ((CheckBox) findViewById(R.id.checkBoxDisplayHz)).setChecked(Settings.DISPLAY_HZ_DEFAULT);
            ((CheckBox) findViewById(R.id.checkBoxDisplayTuner)).setChecked(Settings.DISPLAY_TUNER_DEFAULT);
            ((SeekBar) findViewById(R.id.seekBarTunerSmooth)).setProgress(Settings.TUNER_SMOOTH_DEFAULT - Settings.TUNER_SMOOTH_MIN);
            ((CheckBox) findViewById(R.id.checkBoxDisplayBpm)).setChecked(Settings.DISPLAY_BPM_DEFAULT);
            ((CheckBox) findViewById(R.id.checkBoxDisplayMetronome)).setChecked(Settings.DISPLAY_METRONOME_DEFAULT);
            ((SeekBar) findViewById(R.id.seekBarBpm)).setProgress(Settings.BPM_DEFAULT - Settings.BPM_MIN);
            ((RadioGroup) findViewById(R.id.radioGroupMeter)).check(R.id.radioButtonMeter4);
            ((CheckBox) findViewById(R.id.checkBoxDisplayButtonHold)).setChecked(Settings.DISPLAY_BUTTON_HOLD_DEFAULT);
            ((CheckBox) findViewById(R.id.checkBoxDisplayButtonScale)).setChecked(Settings.DISPLAY_BUTTON_SCALE_DEFAULT);
            ((CheckBox) findViewById(R.id.checkBoxDisplayButtonTempo)).setChecked(Settings.DISPLAY_BUTTON_TEMPO_DEFAULT);
            setButtonColor(R.id.buttonColorPitch, Settings.COLOR_PITCH_DEFAULT);
            setButtonColor(R.id.buttonColorTempo, Settings.COLOR_TEMPO_DEFAULT);
            setButtonColor(R.id.buttonColorMetronome, Settings.COLOR_METRONOME_DEFAULT);
            return true;
        }
    }

    @Override // android.view.View.OnClickListener
    public void onClick(View view) {
        new ColorPopupWindow(this, getLayoutInflater().inflate(R.layout.layout_color, (ViewGroup) null), (ImageButton) view).showAtLocation(getWindow().getDecorView(), 17, 0, 0);
    }
}
