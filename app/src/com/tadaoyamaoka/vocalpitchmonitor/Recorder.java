package com.tadaoyamaoka.vocalpitchmonitor;

import android.media.AudioRecord;
import android.media.AudioTrack;

public class Recorder {
    private static final int AUDIO_BUFFER_SIZE;
    private static final int FRAME_BUFFER_SIZE;
    private static short[] record_data = null;
    private static int record_data_pos = 0;
    private Analyzer analyzer;
    private AudioTrack player;
    private AudioRecord record;
    private Notification notification = new Notification();
    private short[] data = new short[FRAME_BUFFER_SIZE];
    private int RECORD_BUFFER_SIZE = 0;
    private boolean isRecording = false;
    private Runnable recordDoneNotify = null;
    private Runnable playerDoneNotify = null;
    private int record_data_play_pos = 0;

    static /* synthetic */ int access$508() {
        int i = record_data_pos;
        record_data_pos = i + 1;
        return i;
    }

    static {
        int minBufferSize = AudioRecord.getMinBufferSize(44100, 16, 2);
        AUDIO_BUFFER_SIZE = minBufferSize;
        FRAME_BUFFER_SIZE = minBufferSize / 2;
    }

    public void setRecordDoneNotify(Runnable runnable) {
        this.recordDoneNotify = runnable;
    }

    public void setPlayerDoneNotify(Runnable runnable) {
        this.playerDoneNotify = runnable;
    }

    public boolean isPlaying() {
        return this.record_data_play_pos > 0;
    }

    public int get_play_pos() {
        return this.record_data_play_pos;
    }

    /* JADX INFO: Access modifiers changed from: package-private */
    public Recorder(Analyzer analyzer) {
        this.analyzer = analyzer;
        init();
    }

    
    public class Notification implements AudioRecord.OnRecordPositionUpdateListener {
        @Override // android.media.AudioRecord.OnRecordPositionUpdateListener
        public void onMarkerReached(AudioRecord audioRecord) {
        }

        public Notification() {
        }

        @Override // android.media.AudioRecord.OnRecordPositionUpdateListener
        public void onPeriodicNotification(AudioRecord audioRecord) {
            int read = audioRecord.read(Recorder.this.data, 0, Recorder.FRAME_BUFFER_SIZE);
            for (int i = 0; i < read; i++) {
                Recorder.this.analyzer.addData(Recorder.this.data[i]);
                if (Recorder.this.isRecording) {
                    Recorder.record_data[Recorder.access$508()] = Recorder.this.data[i];
                    if (Recorder.record_data_pos >= Recorder.record_data.length) {
                        Recorder.this.isRecording = false;
                        Recorder.this.recordDoneNotify.run();
                    }
                }
            }
        }
    }

    private void init() {
        int maxMemory = (int) ((Runtime.getRuntime().maxMemory() - 5242880) / 5292000.0d);
        if (maxMemory > 5) {
            maxMemory = 5;
        }
        this.RECORD_BUFFER_SIZE = (int) (maxMemory * 2646000.0d);
        AudioRecord audioRecord = new AudioRecord(1, 44100, 16, 2, AUDIO_BUFFER_SIZE);
        this.record = audioRecord;
        audioRecord.setRecordPositionUpdateListener(this.notification);
        AudioRecord audioRecord2 = this.record;
        int i = FRAME_BUFFER_SIZE;
        audioRecord2.setPositionNotificationPeriod(i);
        this.record.startRecording();
        this.record.read(this.data, 0, i);
    }

    public void release() {
        releasePlayer();
        AudioRecord audioRecord = this.record;
        if (audioRecord != null) {
            audioRecord.stop();
            this.record.release();
            this.record = null;
        }
    }

    public void startRecord() {
        initRecordDataIfNotCreated();
        record_data_pos = 0;
        this.isRecording = true;
        this.record_data_play_pos = 0;
    }

    private void initRecordDataIfNotCreated() {
        if (record_data == null) {
            record_data = new short[this.RECORD_BUFFER_SIZE];
        }
    }

    public void stopRecord() {
        this.isRecording = false;
    }

    public void startPlay() {
        release();
        this.analyzer.clearData();
        final int minBufferSize = AudioTrack.getMinBufferSize(44100, 4, 2);
        AudioTrack audioTrack = new AudioTrack(3, 44100, 4, 2, minBufferSize, 1);
        this.player = audioTrack;
        audioTrack.setPositionNotificationPeriod(minBufferSize / 2);
        this.player.setPlaybackPositionUpdateListener(new AudioTrack.OnPlaybackPositionUpdateListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.Recorder.1
            @Override // android.media.AudioTrack.OnPlaybackPositionUpdateListener
            public void onMarkerReached(AudioTrack audioTrack2) {
            }

            @Override // android.media.AudioTrack.OnPlaybackPositionUpdateListener
            public void onPeriodicNotification(AudioTrack audioTrack2) {
                Recorder.this.writePlayData(minBufferSize);
            }
        });
        this.player.play();
        writePlayData(minBufferSize);
        writePlayData(minBufferSize);
        writePlayData(minBufferSize);
    }

    /* JADX INFO: Access modifiers changed from: private */
    public void writePlayData(int i) {
        boolean z;
        int i2 = i / 2;
        int i3 = this.record_data_play_pos;
        int i4 = i3 + i2;
        int i5 = record_data_pos;
        if (i4 > i5) {
            i2 = i5 - i3;
            z = true;
        } else {
            z = false;
        }
        for (int i6 = 0; i6 < i2; i6++) {
            this.analyzer.addData(record_data[this.record_data_play_pos + i6]);
        }
        AudioTrack audioTrack = this.player;
        if (audioTrack != null) {
            audioTrack.write(record_data, this.record_data_play_pos, i2);
            this.record_data_play_pos += i2;
            if (z) {
                stopPlay();
                Runnable runnable = this.playerDoneNotify;
                if (runnable != null) {
                    runnable.run();
                }
            }
        }
    }

    public void stopPlay() {
        releasePlayer();
        this.record_data_play_pos = 0;
        init();
    }

    public void pausePlay() {
        releasePlayer();
    }

    private void releasePlayer() {
        AudioTrack audioTrack = this.player;
        if (audioTrack != null) {
            audioTrack.stop();
            this.player.release();
            this.player = null;
        }
    }

    public boolean hasRecordData() {
        return record_data_pos > 0;
    }

    public int get_record_data_size() {
        return record_data_pos;
    }

    public void set_record_data_size(int i) {
        record_data_pos = i;
    }

    public short[] get_record_data() {
        return record_data;
    }

    public short[] get_record_data_for_write() {
        initRecordDataIfNotCreated();
        return record_data;
    }
}
