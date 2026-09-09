package com.tadaoyamaoka.vocalpitchmonitor;

import android.os.Handler;
import android.view.MotionEvent;
import android.view.View;

public class LongClickRepeatAdapter {
    private static final int REPEAT_INTERVAL = 100;

    public static void bless(View view) {
        bless(100, view);
    }

    public static void bless(final int i, final View view) {
        final Handler handler = new Handler();
        final BooleanWrapper booleanWrapper = new BooleanWrapper(false);
        final Runnable runnable = new Runnable() { // from class: com.tadaoyamaoka.vocalpitchmonitor.LongClickRepeatAdapter.1
            @Override // java.lang.Runnable
            public void run() {
                if (booleanWrapper.value) {
                    view.performClick();
                    handler.postDelayed(this, i);
                }
            }
        };
        view.setOnLongClickListener(new View.OnLongClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.LongClickRepeatAdapter.2
            @Override // android.view.View.OnLongClickListener
            public boolean onLongClick(View view2) {
                booleanWrapper.value = true;
                handler.post(runnable);
                return true;
            }
        });
        view.setOnTouchListener(new View.OnTouchListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.LongClickRepeatAdapter.3
            @Override // android.view.View.OnTouchListener
            public boolean onTouch(View view2, MotionEvent motionEvent) {
                if (motionEvent.getAction() == 1) {
                    booleanWrapper.value = false;
                }
                return false;
            }
        });
    }

    /* JADX INFO: Access modifiers changed from: private */
    
    public static class BooleanWrapper {
        public boolean value;

        public BooleanWrapper(boolean z) {
            this.value = z;
        }
    }
}
