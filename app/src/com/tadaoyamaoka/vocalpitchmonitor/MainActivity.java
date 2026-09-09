package com.tadaoyamaoka.vocalpitchmonitor;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.ImageButton;
import android.widget.PopupMenu;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.Toast;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStream;
import java.io.ObjectInputStream;
import java.io.ObjectOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.HashMap;
import java.util.List;

/**
 * Main activity: pitch monitor display, record/playback, scale selection and
 * tuning-config importing.
 *
 * Ad-free port of the original VocalPitchMonitor MainActivity, extended with
 * musescore-xen-tuner tuning-config support:
 *  - "Import tuning config…" loads a .txt/.json config via the system file
 *    picker (Storage Access Framework);
 *  - the chosen file's URI, display name and a parsed cache are remembered in
 *    preferences, so the config is re-applied automatically on every launch
 *    and survives app restarts / file-permission loss;
 *  - the custom scale is drawn and recognized exactly per the config grammar.
 */
public class MainActivity extends Activity {
    private static final int REQ_SETTINGS = 0;
    private static final int REQ_LOAD = 1;
    private static final int REQ_IMPORT_WAV = 2;
    private static final int REQ_IMPORT_CONFIG = 3;

    private static String record_analyze_cnt_file_name = "record_analyze_cnt";
    private Recorder recorder;
    final Handler handler = new Handler();
    private boolean bHold = false;
    private Analyzer analyzer = new Analyzer();
    private String fileName = null;
    SimpleDateFormat sdf = new SimpleDateFormat("yyyyMMdd-HHmmss");
    private int record_analyze_cnt = 0;

    private MainSurfaceView mainSurfaceView;
    private Settings settings;
    private ScaleConfig scaleConfig = null;

    /** Bundled default tuning config (res/raw). */
    private static final String DEFAULT_SCALE_NAME = "7ed2 on C";

    @Override
    protected void onCreate(Bundle bundle) {
        super.onCreate(bundle);
        getWindow().addFlags(128); // FLAG_KEEP_SCREEN_ON
        setContentView(R.layout.activity_main);
        this.mainSurfaceView = (MainSurfaceView) findViewById(R.id.MainSurfaceView);
        this.mainSurfaceView.setAnalyzer(this.analyzer);
        this.settings = new Settings(this);
        loadSettings();

        Button button = (Button) findViewById(R.id.btnHold);
        button.setTextColor(0xFF888888);
        button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                Button button2 = (Button) view;
                if (!MainActivity.this.bHold) {
                    button2.setTextColor(0xFFFFFFFF);
                    mainSurfaceView.hold();
                    MainActivity.this.bHold = true;
                    return;
                }
                button2.setTextColor(0xFF444444);
                mainSurfaceView.unHold();
                MainActivity.this.bHold = false;
            }
        });

        final ImageButton imageButton = (ImageButton) findViewById(R.id.btnStop);
        final ImageButton imageButton2 = (ImageButton) findViewById(R.id.btnRecord);
        final ImageButton imageButton3 = (ImageButton) findViewById(R.id.btnPlay);
        imageButton.setEnabled(false);
        imageButton.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (imageButton2.isSelected()) {
                    MainActivity.this.recorder.stopRecord();
                } else {
                    MainActivity.this.recorder.stopPlay();
                }
                imageButton.setEnabled(false);
                imageButton2.setSelected(false);
                imageButton2.setEnabled(true);
                imageButton3.setEnabled(true);
                imageButton3.setSelected(false);
            }
        });
        imageButton2.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                MainActivity.this.recorder.setRecordDoneNotify(new Runnable() {
                    @Override
                    public void run() {
                        MainActivity.this.handler.post(new Runnable() {
                            @Override
                            public void run() {
                                imageButton.setEnabled(false);
                                imageButton2.setSelected(false);
                                imageButton2.setEnabled(true);
                                imageButton3.setEnabled(true);
                                imageButton3.setSelected(false);
                            }
                        });
                    }
                });
                MainActivity.this.recorder.startRecord();
                imageButton2.setSelected(true);
                imageButton.setEnabled(true);
                imageButton3.setEnabled(false);
                MainActivity.this.fileName = null;
                MainActivity.this.record_analyze_cnt = MainActivity.this.analyzer.get_total_analyze_cnt();
            }
        });
        imageButton3.setEnabled(false);
        imageButton3.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if (imageButton3.isSelected()) {
                    MainActivity.this.recorder.pausePlay();
                    imageButton3.setSelected(false);
                    imageButton.setEnabled(true);
                    return;
                }
                if (MainActivity.this.recorder.isPlaying()) {
                    MainActivity.this.analyzer.set_total_analyze_cnt(MainActivity.this.record_analyze_cnt + (MainActivity.this.recorder.get_play_pos() / Analyzer.ANALYZE_INTERVAL));
                } else if (MainActivity.this.record_analyze_cnt == 0) {
                    MainActivity.this.record_analyze_cnt = MainActivity.this.analyzer.get_total_analyze_cnt();
                } else {
                    MainActivity.this.analyzer.set_total_analyze_cnt(MainActivity.this.record_analyze_cnt);
                }
                MainActivity.this.recorder.startPlay();
                imageButton3.setSelected(true);
                imageButton2.setEnabled(false);
                imageButton.setEnabled(true);
            }
        });

        ((TextView) findViewById(R.id.textViewCurrentScale)).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                showScaleDialog();
            }
        });

        View inflate = LayoutInflater.from(this).inflate(R.layout.layout_bpm, (ViewGroup) findViewById(R.id.dialog_bpm));
        final SeekBar seekBar = (SeekBar) inflate.findViewById(R.id.seekBarBpmInDialog);
        seekBar.setMax(Settings.BPM_MAX - Settings.BPM_MIN);
        final TextView textView = (TextView) inflate.findViewById(R.id.textViewBpmValInDialog);
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onStartTrackingTouch(SeekBar seekBar2) {
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar2) {
            }

            @Override
            public void onProgressChanged(SeekBar seekBar2, int i, boolean z) {
                textView.setText(String.valueOf(seekBar2.getProgress() + Settings.BPM_MIN));
            }
        });
        inflate.findViewById(R.id.buttonBPMDown).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                SeekBar seekBar2 = seekBar;
                seekBar2.setProgress(seekBar2.getProgress() - 1);
            }
        });
        inflate.findViewById(R.id.buttonBPMUp).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                SeekBar seekBar2 = seekBar;
                seekBar2.setProgress(seekBar2.getProgress() + 1);
            }
        });
        final CheckBox checkBox = (CheckBox) inflate.findViewById(R.id.checkBoxDisplayBpm);
        final CheckBox checkBox2 = (CheckBox) inflate.findViewById(R.id.checkBoxDisplayMetronome);
        AlertDialog.Builder builder = new AlertDialog.Builder(this);
        builder.setView(inflate);
        builder.setPositiveButton("OK", new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                boolean isChecked = checkBox.isChecked();
                settings.setDisplayBpm(isChecked);
                int progress = seekBar.getProgress() + Settings.BPM_MIN;
                settings.setBpm(progress);
                boolean isChecked2 = checkBox2.isChecked();
                settings.setDisplayMetronome(isChecked2);
                settings.commit();
                MainActivity.this.updateBpm(isChecked, progress, isChecked2);
            }
        });
        final AlertDialog create = builder.create();
        ((TextView) findViewById(R.id.textViewBpm)).setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                checkBox.setChecked(settings.getDisplayBpm());
                int bpm = settings.getBpm();
                seekBar.setProgress(bpm - Settings.BPM_MIN);
                textView.setText(String.valueOf(bpm));
                checkBox2.setChecked(settings.getDisplayMetronome());
                create.show();
            }
        });
    }

    /** Scale picker dialog: bundled default + imported configs + import action. */
    private void showScaleDialog() {
        final List<String> items = new ArrayList<String>();
        items.add(DEFAULT_SCALE_NAME);
        final String cfgName = settings.getConfigName();
        if (cfgName != null && !cfgName.equals(DEFAULT_SCALE_NAME)) {
            items.add(cfgName);
        }
        final int importIdx = items.size();
        items.add(getString(R.string.action_import_config));
        final String[] itemArr = items.toArray(new String[0]);
        String scale = settings.getScale();
        int checked = 0;
        for (int i = 0; i < itemArr.length; i++) {
            if (itemArr[i].equals(scale)) {
                checked = i;
            }
        }
        AlertDialog.Builder b = new AlertDialog.Builder(this);
        b.setTitle(getResources().getString(R.string.settings_scale));
        b.setSingleChoiceItems(itemArr, checked, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                if (i == importIdx) {
                    dialogInterface.dismiss();
                    startImportConfig();
                    return;
                }
                settings.setScale(itemArr[i]);
                settings.commit();
                MainActivity.this.loadScaleSetting();
                dialogInterface.dismiss();
            }
        });
        b.create().show();
    }

    private void startImportConfig() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.putExtra(Intent.EXTRA_MIME_TYPES, new String[]{"text/plain", "text/*", "application/json", "application/octet-stream", "*/*"});
        try {
            startActivityForResult(intent, REQ_IMPORT_CONFIG);
        } catch (Exception e) {
            // fall back to a plain GET_CONTENT picker
            Intent i2 = new Intent(Intent.ACTION_GET_CONTENT);
            i2.setType("*/*");
            startActivityForResult(i2, REQ_IMPORT_CONFIG);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (android.os.Build.VERSION.SDK_INT >= 23) {
            if (checkSelfPermission("android.permission.RECORD_AUDIO") != 0) {
                requestPermissions(new String[]{"android.permission.RECORD_AUDIO"}, 0);
                return;
            }
        }
        resume();
    }

    @Override
    public void onRequestPermissionsResult(int i, String[] strArr, int[] iArr) {
        if (i == 0) {
            if (iArr.length <= 0 || iArr[0] != 0) {
                finish();
                return;
            }
            resume();
        }
    }

    private void resume() {
        if (this.recorder == null) {
            this.recorder = new Recorder(this.analyzer);
        }
        final ImageButton imageButton = (ImageButton) findViewById(R.id.btnStop);
        final ImageButton imageButton2 = (ImageButton) findViewById(R.id.btnRecord);
        final ImageButton imageButton3 = (ImageButton) findViewById(R.id.btnPlay);
        this.recorder.setPlayerDoneNotify(new Runnable() {
            @Override
            public void run() {
                MainActivity.this.handler.post(new Runnable() {
                    @Override
                    public void run() {
                        imageButton3.setSelected(false);
                        imageButton2.setEnabled(true);
                        imageButton.setEnabled(false);
                    }
                });
            }
        });
        imageButton.setEnabled(false);
        imageButton2.setSelected(false);
        imageButton2.setEnabled(true);
        if (this.recorder.hasRecordData()) {
            imageButton3.setEnabled(true);
        } else {
            imageButton3.setEnabled(false);
        }
        imageButton3.setSelected(false);
        mainSurfaceView.setCurrentHorizontalZooming(settings.getHorizontalZooming());
        mainSurfaceView.setCurrentVerticalZooming(settings.getVerticalZooming());
        mainSurfaceView.setBottomCent(settings.getBottomCent());
    }

    @Override
    protected void onPause() {
        Recorder recorder = this.recorder;
        if (recorder != null) {
            recorder.release();
            this.recorder = null;
        }
        settings.setHorizontalZooming(mainSurfaceView.getCurrentHorizontalZooming());
        settings.setVerticalZooming(mainSurfaceView.getCurrentVerticalZooming());
        settings.setBottomCent(mainSurfaceView.getBottomCent());
        settings.commit();
        super.onPause();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onPrepareOptionsMenu(Menu menu) {
        for (int i = 0; i < menu.size(); i++) {
            MenuItem item = menu.getItem(i);
            if (item.getItemId() == R.id.action_save) {
                item.setEnabled(this.recorder != null && this.recorder.hasRecordData());
            }
        }
        return super.onPrepareOptionsMenu(menu);
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem menuItem) {
        switch (menuItem.getItemId()) {
            case R.id.action_import_config:
                startImportConfig();
                return true;
            case R.id.action_import:
                Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
                intent.setType("audio/*");
                startActivityForResult(intent, REQ_IMPORT_WAV);
                return true;
            case R.id.action_load:
                startActivityForResult(new Intent(this, LoadActivity.class), REQ_LOAD);
                return true;
            case R.id.action_save:
                save();
                return true;
            case R.id.action_settings:
                settings.setHorizontalZooming(mainSurfaceView.getCurrentHorizontalZooming());
                settings.setVerticalZooming(mainSurfaceView.getCurrentVerticalZooming());
                settings.commit();
                startActivityForResult(new Intent(this, SettingsActivity.class), REQ_SETTINGS);
                return true;
            default:
                return super.onOptionsItemSelected(menuItem);
        }
    }

    public void onMenuClick(View view) {
        PopupMenu popupMenu = new PopupMenu(this, view);
        Menu menu = popupMenu.getMenu();
        getMenuInflater().inflate(R.menu.menu_main, menu);
        for (int i = 0; i < menu.size(); i++) {
            MenuItem item = menu.getItem(i);
            if (item.getItemId() == R.id.action_save) {
                item.setEnabled(this.recorder != null && this.recorder.hasRecordData());
            }
        }
        popupMenu.setOnMenuItemClickListener(new PopupMenu.OnMenuItemClickListener() {
            @Override
            public boolean onMenuItemClick(MenuItem menuItem) {
                MainActivity.this.onOptionsItemSelected(menuItem);
                return true;
            }
        });
        popupMenu.show();
    }

    @Override
    protected void onActivityResult(int i, int i2, Intent intent) {
        if (i == REQ_SETTINGS) {
            loadSettings();
        } else if (i == REQ_IMPORT_CONFIG) {
            if (i2 == RESULT_OK && intent != null && intent.getData() != null) {
                handleConfigImport(intent.getData());
            }
        } else if (i == REQ_LOAD) {
            if (i2 == RESULT_OK) {
                final String stringExtra = intent.getStringExtra("FILE_NAME");
                new Handler().post(new Runnable() {
                    @Override
                    public void run() {
                        Toast toast;
                        if (MainActivity.this.recorder == null) {
                            MainActivity.this.recorder = new Recorder(MainActivity.this.analyzer);
                        }
                        boolean loadRecordData = MainActivity.this.loadRecordData(stringExtra);
                        if (loadRecordData) {
                            MainActivity.this.fileName = stringExtra;
                        }
                        if (loadRecordData) {
                            try {
                                ObjectInputStream objectInputStream = new ObjectInputStream(MainActivity.this.openFileInput(record_analyze_cnt_file_name));
                                Integer num = (Integer) ((HashMap) objectInputStream.readObject()).get(stringExtra);
                                objectInputStream.close();
                                if (num != null) {
                                    MainActivity.this.record_analyze_cnt = num.intValue();
                                } else {
                                    MainActivity.this.record_analyze_cnt = 0;
                                }
                            } catch (IOException | ClassNotFoundException unused) {
                            }
                        }
                        if (loadRecordData) {
                            toast = Toast.makeText(MainActivity.this, R.string.msg_loaded, Toast.LENGTH_SHORT);
                            ((ImageButton) MainActivity.this.findViewById(R.id.btnPlay)).setEnabled(true);
                        } else {
                            toast = Toast.makeText(MainActivity.this, R.string.msg_loaded_fail, Toast.LENGTH_SHORT);
                        }
                        toast.setGravity(17, 0, 0);
                        toast.show();
                    }
                });
            }
        } else if (i == REQ_IMPORT_WAV) {
            if (i2 == RESULT_OK && intent != null && intent.getData() != null) {
                final Uri data = intent.getData();
                new Handler().post(new Runnable() {
                    @Override
                    public void run() {
                        if (MainActivity.this.recorder == null) {
                            MainActivity.this.recorder = new Recorder(MainActivity.this.analyzer);
                        }
                        String fileName = MainActivity.this.getFileName(data);
                        if (fileName == null || !fileName.endsWith(".wav")) {
                            Toast makeText = Toast.makeText(MainActivity.this, R.string.msg_filename_error, Toast.LENGTH_LONG);
                            makeText.setGravity(17, 0, 0);
                            makeText.show();
                        } else if (MainActivity.this.getFileStreamPath(fileName).exists()) {
                            Toast makeText2 = Toast.makeText(MainActivity.this, R.string.msg_fileexists_error, Toast.LENGTH_LONG);
                            makeText2.setGravity(17, 0, 0);
                            makeText2.show();
                        } else if (!MainActivity.this.loadRecordData(data)) {
                            Toast makeText3 = Toast.makeText(MainActivity.this, R.string.msg_imported_fail, Toast.LENGTH_SHORT);
                            makeText3.setGravity(17, 0, 0);
                            makeText3.show();
                        } else if (!MainActivity.this.saveRecordData(fileName)) {
                            Toast makeText4 = Toast.makeText(MainActivity.this, R.string.msg_saved_fail, Toast.LENGTH_SHORT);
                            makeText4.setGravity(17, 0, 0);
                            makeText4.show();
                        } else {
                            MainActivity.this.fileName = fileName;
                            Toast makeText5 = Toast.makeText(MainActivity.this, R.string.msg_imported, Toast.LENGTH_SHORT);
                            makeText5.setGravity(17, 0, 0);
                            makeText5.show();
                            ((ImageButton) MainActivity.this.findViewById(R.id.btnPlay)).setEnabled(true);
                        }
                    }
                });
            }
        }
    }

    /* ---------------- tuning config import ---------------- */

    private void handleConfigImport(Uri uri) {
        try {
            tryTakePersistablePermission(uri);
            String text = readText(uri);
            String name = getFileName(uri);
            if (name != null) {
                name = name.replaceAll("(?i)\\.(txt|json)$", "");
            }
            if (name == null || name.length() == 0) {
                name = "Custom Scale";
            }
            ScaleConfig cfg = ScaleConfig.parse(text, name);
            if (cfg.error != null) {
                Toast t = Toast.makeText(this, getString(R.string.config_parse_fail, cfg.error), Toast.LENGTH_LONG);
                t.setGravity(17, 0, 0);
                t.show();
                return;
            }
            settings.setConfigUri(uri.toString());
            settings.setConfigName(name);
            settings.setConfigPayload(cfg.toPayload());
            settings.setScale(name);
            settings.commit();
            this.scaleConfig = cfg;
            loadScaleSetting();
            Toast t = Toast.makeText(this, getString(R.string.msg_imported) + ": " + name, Toast.LENGTH_SHORT);
            t.setGravity(17, 0, 0);
            t.show();
        } catch (Exception e) {
            Toast t = Toast.makeText(this, R.string.config_load_fail, Toast.LENGTH_LONG);
            t.setGravity(17, 0, 0);
            t.show();
        }
    }

    /**
     * Keep the Storage-Access-Framework read grant across app restarts so the
     * config file can be re-read on every launch. Invoked reflectively because
     * some SDK stub jars omit the (API 19+) method; on real devices it is
     * always present. If it fails, the cached payload still keeps the scale.
     */
    private void tryTakePersistablePermission(Uri uri) {
        try {
            java.lang.reflect.Method m = android.content.Context.class.getMethod(
                    "takePersistableUriPermission", android.net.Uri.class, int.class);
            m.invoke(this, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } catch (Throwable t) {
            // non-critical
        }
    }

    private String readText(Uri uri) throws IOException {
        InputStream is = getContentResolver().openInputStream(uri);
        if (is == null) {
            throw new IOException("cannot open " + uri);
        }
        try {
            java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
            byte[] buf = new byte[4096];
            int n;
            while ((n = is.read(buf)) > 0) {
                bos.write(buf, 0, n);
            }
            return new String(bos.toByteArray(), "UTF-8");
        } finally {
            is.close();
        }
    }

    /**
     * Resolve the active ScaleConfig for the current scale selection:
     * fresh re-read of the remembered file first, then the cached payload.
     */
    private ScaleConfig resolveScaleConfig() {
        String cfgName = settings.getConfigName();
        if (cfgName == null) {
            return null;
        }
        ScaleConfig cfg = null;
        String uriStr = settings.getConfigUri();
        if (uriStr != null) {
            try {
                Uri uri = Uri.parse(uriStr);
                String text = readText(uri);
                cfg = ScaleConfig.parse(text, cfgName);
                if (cfg.error == null) {
                    settings.setConfigPayload(cfg.toPayload());
                } else {
                    cfg = null;
                }
            } catch (Exception e) {
                cfg = null;
            }
        }
        if (cfg == null) {
            cfg = ScaleConfig.fromPayload(settings.getConfigPayload());
        }
        return cfg;
    }

    /* ---------------- settings & scale application ---------------- */

    private void loadSettings() {
        Settings s = this.settings;
        s.checkVersion();
        double threshold = s.getThreshold();
        float horizontalZooming = s.getHorizontalZooming();
        float verticalZooming = s.getVerticalZooming();
        // "Semitone" is not well defined for arbitrary tuning scales: the
        // semitone settings were removed from the UI and are always off.
        boolean indicateSemitone = false;
        boolean displaySemitone = false;
        int i2 = 1;                 // temperament settings removed: fixed A4 octave
        int calibration = 440;      // calibration fixed at A4 = 440 Hz
        int transpose = 0;          // transpose fixed at C
        boolean autoScroll = s.getAutoScroll();
        int scrollSpeed = s.getScrollSpeed();
        boolean displayHz = s.getDisplayHz();
        boolean displayTuner = s.getDisplayTuner();
        int tunerSmooth = s.getTunerSmooth();
        boolean equals = false;     // note-name mode removed (config names always used)
        boolean displayBpm = s.getDisplayBpm();
        boolean displayMetronome = s.getDisplayMetronome();
        int bpm = s.getBpm();
        int i;
        if ("4/4".equals(s.getMeter())) {
            i = 4;
        } else {
            i = "3/4".equals(s.getMeter()) ? 3 : 0;
        }
        int[] iArr = {s.getColor1(), 0, s.getColor2(), s.getColor3(), s.getColor3(), s.getColor4(), 0, s.getColor5(), s.getColor6(), s.getColor6(), s.getColor7(), s.getColor7()};
        int[] iArr2 = new int[12];
        for (int i3 = 0; i3 < 12; i3++) {
            iArr2[i3] = s.getColorChromatic(i3);
        }
        mainSurfaceView.updateSettings(threshold, horizontalZooming, verticalZooming, indicateSemitone, displaySemitone,
                i2, calibration, transpose, autoScroll, scrollSpeed, s.getColorPitch(), s.getColorTempo(),
                s.getColorMetronome(), iArr, s.getColorSemitone(), iArr2, displayHz, displayTuner, tunerSmooth, equals, i);
        findViewById(R.id.btnHold).setVisibility(s.getDisplayButtonHold() ? View.VISIBLE : View.GONE);
        findViewById(R.id.textViewCurrentScale).setVisibility(s.getDisplayButtonScale() ? View.VISIBLE : View.GONE);
        findViewById(R.id.textViewBpm).setVisibility(s.getDisplayButtonTempo() ? View.VISIBLE : View.GONE);
        findViewById(R.id.textViewBpmUnit).setVisibility(s.getDisplayButtonTempo() ? View.VISIBLE : View.GONE);
        loadScaleSetting();
        updateBpm(displayBpm, bpm, displayMetronome);
    }

    private void updateBpm(boolean z, int i, boolean z2) {
        if (z || z2) {
            ((TextView) findViewById(R.id.textViewBpm)).setTextColor(0xFFFFFFFF);
            ((TextView) findViewById(R.id.textViewBpmUnit)).setTextColor(0xFFFFFFFF);
        } else {
            ((TextView) findViewById(R.id.textViewBpm)).setTextColor(0xFF444444);
            ((TextView) findViewById(R.id.textViewBpmUnit)).setTextColor(0xFF444444);
        }
        ((TextView) findViewById(R.id.textViewBpm)).setText(Integer.toString(i));
        mainSurfaceView.updateBpm(z, i, z2);
    }

    /** Apply the current tuning-config scale (bundled default or imported). */
    private void loadScaleSetting() {
        String scale = settings.getScale();
        if (scale == null || scale.length() == 0) {
            scale = DEFAULT_SCALE_NAME;
        }
        ScaleConfig cfg = null;
        if (DEFAULT_SCALE_NAME.equals(scale)) {
            cfg = loadBundledConfig();
        } else if (isConfigScaleName(scale)) {
            cfg = resolveScaleConfig();
        }
        if (cfg != null && cfg.error == null) {
            this.scaleConfig = cfg;
            mainSurfaceView.updateScaleConfig(cfg);
            ((TextView) findViewById(R.id.textViewCurrentScale)).setText(scale);
            return;
        }
        // unavailable (e.g. deleted import) → always fall back to the bundled default
        this.scaleConfig = null;
        ScaleConfig def = loadBundledConfig();
        if (def != null) {
            this.scaleConfig = def;
            mainSurfaceView.updateScaleConfig(def);
        } else {
            mainSurfaceView.updateScaleConfig(null);
        }
        ((TextView) findViewById(R.id.textViewCurrentScale)).setText(DEFAULT_SCALE_NAME);
        if (!DEFAULT_SCALE_NAME.equals(scale)) {
            settings.setScale(DEFAULT_SCALE_NAME);
            settings.commit();
            Toast t = Toast.makeText(this, R.string.config_load_fail, Toast.LENGTH_LONG);
            t.setGravity(17, 0, 0);
            t.show();
        }
    }

    /** Read and parse the bundled default tuning config (res/raw). */
    private ScaleConfig loadBundledConfig() {
        try {
            java.io.InputStream is = getResources().openRawResource(R.raw.seven_ed2_on_c);
            java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
            byte[] buf = new byte[4096];
            int n;
            while ((n = is.read(buf)) > 0) {
                bos.write(buf, 0, n);
            }
            is.close();
            return ScaleConfig.parse(new String(bos.toByteArray(), "UTF-8"), DEFAULT_SCALE_NAME);
        } catch (Exception e) {
            return null;
        }
    }

    private boolean isConfigScaleName(String scale) {
        String cfgName = settings.getConfigName();
        return cfgName != null && cfgName.equals(scale);
    }

    /* ---------------- wav record data (unchanged from original) ---------------- */

    private boolean save() {
        boolean saveRecordData = saveRecordData(this.sdf.format(new Date()) + ".wav");
        if (saveRecordData) {
            HashMap hashMap = null;
            try {
                ObjectInputStream objectInputStream = new ObjectInputStream(openFileInput(record_analyze_cnt_file_name));
                hashMap = (HashMap) objectInputStream.readObject();
                objectInputStream.close();
            } catch (Exception unused) {
            }
            if (hashMap == null) {
                hashMap = new HashMap();
            }
            hashMap.put(this.fileName, Integer.valueOf(this.record_analyze_cnt));
            try {
                ObjectOutputStream objectOutputStream = new ObjectOutputStream(openFileOutput(record_analyze_cnt_file_name, 0));
                objectOutputStream.writeObject(hashMap);
                objectOutputStream.close();
            } catch (IOException unused3) {
            }
        }
        Toast toast;
        if (saveRecordData) {
            toast = Toast.makeText(this, R.string.msg_saved, Toast.LENGTH_SHORT);
        } else {
            toast = Toast.makeText(this, R.string.msg_saved_fail, Toast.LENGTH_SHORT);
        }
        toast.setGravity(17, 0, 0);
        toast.show();
        return saveRecordData;
    }

    private String getFileName(Uri uri) {
        String str = null;
        if (uri.getScheme().equals("content")) {
            Cursor query = getContentResolver().query(uri, null, null, null, null);
            if (query != null) {
                try {
                    if (query.moveToFirst()) {
                        str = query.getString(query.getColumnIndex("_display_name"));
                    }
                } finally {
                    query.close();
                }
            }
        }
        if (str != null) {
            return str;
        }
        String path = uri.getPath();
        int lastIndexOf = path.lastIndexOf(47);
        return lastIndexOf != -1 ? path.substring(lastIndexOf + 1) : path;
    }

    private boolean saveRecordData(String str) {
        BufferedOutputStream bufferedOutputStream = null;
        try {
            try {
                bufferedOutputStream = new BufferedOutputStream(openFileOutput(str, 0));
            } catch (IOException e) {
                e.printStackTrace();
                return false;
            }
            short[] sArr = this.recorder.get_record_data();
            int i = this.recorder.get_record_data_size();
            bufferedOutputStream.write("RIFF".getBytes());
            int i2 = i * 2;
            bufferedOutputStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(i2 + 36).array());
            bufferedOutputStream.write("WAVE".getBytes());
            bufferedOutputStream.write("fmt ".getBytes());
            bufferedOutputStream.write(new byte[]{16, 0, 0, 0});
            bufferedOutputStream.write(new byte[]{1, 0});
            bufferedOutputStream.write(new byte[]{1, 0});
            bufferedOutputStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(44100).array());
            bufferedOutputStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(88200).array());
            bufferedOutputStream.write(new byte[]{2, 0});
            bufferedOutputStream.write(new byte[]{16, 0});
            bufferedOutputStream.write("data".getBytes());
            bufferedOutputStream.write(ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN).putInt(i2).array());
            ByteBuffer order = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN);
            for (int i3 = 0; i3 < i; i3++) {
                bufferedOutputStream.write(order.putShort(0, sArr[i3]).array());
            }
            try {
                bufferedOutputStream.close();
            } catch (IOException e5) {
                e5.printStackTrace();
            }
            this.fileName = str;
            return true;
        } catch (IOException e8) {
            e8.printStackTrace();
            if (bufferedOutputStream != null) {
                try {
                    bufferedOutputStream.close();
                } catch (IOException e7) {
                    e7.printStackTrace();
                }
            }
            return false;
        }
    }

    private boolean loadRecordData(String str) {
        try {
            return loadRecordData(openFileInput(str));
        } catch (FileNotFoundException unused) {
            return false;
        }
    }

    private boolean loadRecordData(Uri uri) {
        try {
            return loadRecordData(getContentResolver().openInputStream(uri));
        } catch (FileNotFoundException unused) {
            return false;
        }
    }

    private boolean loadRecordData(InputStream inputStream) {
        BufferedInputStream bufferedInputStream2 = new BufferedInputStream(inputStream);
        try {
            try {
                byte[] bArr = new byte[2];
                ByteBuffer order = ByteBuffer.allocate(2).order(ByteOrder.LITTLE_ENDIAN);
                byte[] bArr2 = new byte[4];
                ByteBuffer order2 = ByteBuffer.allocate(4).order(ByteOrder.LITTLE_ENDIAN);
                int available = bufferedInputStream2.available();
                if (bufferedInputStream2.read(bArr2) == 4 && Arrays.equals("RIFF".getBytes(), bArr2)) {
                    int read = bufferedInputStream2.read(bArr2);
                    int i3 = order2.put(bArr2).getInt(0);
                    if (read == 4 && i3 == available - 8) {
                        if (bufferedInputStream2.read(bArr2) == 4 && Arrays.equals("WAVE".getBytes(), bArr2)) {
                            int read2 = bufferedInputStream2.read(bArr2);
                            int i;
                            if (read2 != 4 || !Arrays.equals("JUNK".getBytes(), bArr2)) {
                                i = 0;
                            } else if (bufferedInputStream2.read(bArr2) != 4) {
                                bufferedInputStream2.close();
                                return false;
                            } else {
                                int i4 = order2.compact().put(bArr2).getInt(0);
                                bufferedInputStream2.skip(i4);
                                i = i4;
                                read2 = bufferedInputStream2.read(bArr2);
                            }
                            if (read2 == 4 && Arrays.equals("fmt ".getBytes(), bArr2)) {
                                byte[] bArr3 = {16, 0, 0, 0};
                                if (bufferedInputStream2.read(bArr2) == 4 && Arrays.equals(bArr3, bArr2)) {
                                    byte[] bArr4 = {1, 0};
                                    if (bufferedInputStream2.read(bArr) == 2 && Arrays.equals(bArr4, bArr)) {
                                        byte[] bArr5 = {1, 0};
                                        byte[] bArr6 = {2, 0};
                                        int i2;
                                        if (bufferedInputStream2.read(bArr) != 2) {
                                            bufferedInputStream2.close();
                                            return false;
                                        }
                                        if (Arrays.equals(bArr5, bArr)) {
                                            i2 = 1;
                                        } else if (Arrays.equals(bArr6, bArr)) {
                                            i2 = 2;
                                        } else {
                                            bufferedInputStream2.close();
                                            return false;
                                        }
                                        int read3 = bufferedInputStream2.read(bArr2);
                                        int i5 = order2.compact().put(bArr2).getInt(0);
                                        if (read3 == 4 && i5 == 44100) {
                                            int read4 = bufferedInputStream2.read(bArr2);
                                            int i6 = order2.compact().put(bArr2).getInt(0);
                                            if (read4 == 4 && i6 == 88200 * i2) {
                                                int i7 = i2 * 2;
                                                byte[] bArr7 = {(byte) i7, 0};
                                                if (bufferedInputStream2.read(bArr) == 2 && Arrays.equals(bArr7, bArr)) {
                                                    byte[] bArr8 = {16, 0};
                                                    if (bufferedInputStream2.read(bArr) == 2 && Arrays.equals(bArr8, bArr)) {
                                                        if (bufferedInputStream2.read(bArr2) == 4 && Arrays.equals("data".getBytes(), bArr2)) {
                                                            if (bufferedInputStream2.read(bArr2) != 4) {
                                                                bufferedInputStream2.close();
                                                                return false;
                                                            }
                                                            int i8 = order2.compact().put(bArr2).getInt(0);
                                                            if (i8 > (available - 44) - i) {
                                                                bufferedInputStream2.close();
                                                                return false;
                                                            }
                                                            short[] sArr = this.recorder.get_record_data_for_write();
                                                            int i9 = i8 / i7;
                                                            if (i9 > sArr.length) {
                                                                bufferedInputStream2.close();
                                                                return false;
                                                            }
                                                            for (int i10 = 0; i10 < i9; i10++) {
                                                                int i11 = 0;
                                                                for (int i12 = 0; i12 < i2; i12++) {
                                                                    if (bufferedInputStream2.read(bArr) != 2) {
                                                                        bufferedInputStream2.close();
                                                                        return false;
                                                                    }
                                                                    i11 += order.put(bArr).getShort(0);
                                                                    order.compact();
                                                                }
                                                                sArr[i10] = (short) (i11 / i2);
                                                            }
                                                            this.recorder.set_record_data_size(i9);
                                                            bufferedInputStream2.close();
                                                            return true;
                                                        }
                                                        bufferedInputStream2.close();
                                                        return false;
                                                    }
                                                    bufferedInputStream2.close();
                                                    return false;
                                                }
                                                bufferedInputStream2.close();
                                                return false;
                                            }
                                            bufferedInputStream2.close();
                                            return false;
                                        }
                                        bufferedInputStream2.close();
                                        return false;
                                    }
                                    bufferedInputStream2.close();
                                    return false;
                                }
                                bufferedInputStream2.close();
                                return false;
                            }
                            bufferedInputStream2.close();
                            return false;
                        }
                        bufferedInputStream2.close();
                        return false;
                    }
                    bufferedInputStream2.close();
                    return false;
                }
                bufferedInputStream2.close();
                return false;
            } catch (IOException unused20) {
                if (bufferedInputStream2 != null) {
                    try {
                        bufferedInputStream2.close();
                    } catch (IOException unused21) {
                    }
                }
                return false;
            }
        } catch (Exception unused24) {
            return false;
        }
    }
}