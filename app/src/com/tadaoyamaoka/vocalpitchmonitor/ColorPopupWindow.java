package com.tadaoyamaoka.vocalpitchmonitor;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.drawable.ColorDrawable;
import android.view.View;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.PopupWindow;
import android.widget.SeekBar;
import android.widget.TextView;


public class ColorPopupWindow extends PopupWindow {
    public ColorPopupWindow(Context context, View view, final ImageButton imageButton) {
        super(context);
        int color = getColor((ColorDrawable) imageButton.getDrawable());
        int i = (color >> 16) & 255;
        int i2 = (color >> 8) & 255;
        int i3 = color & 255;
        setWidth(-1);
        setHeight(-2);
        setOutsideTouchable(true);
        setContentView(view);
        View contentView = getContentView();
        final ImageView imageView = (ImageView) contentView.findViewById(R.id.imageViewRGBColor);
        final TextView textView = (TextView) contentView.findViewById(R.id.textViewRValue);
        final TextView textView2 = (TextView) contentView.findViewById(R.id.textViewGValue);
        final TextView textView3 = (TextView) contentView.findViewById(R.id.textViewBValue);
        final SeekBar seekBar = (SeekBar) contentView.findViewById(R.id.seekBarR);
        final SeekBar seekBar2 = (SeekBar) contentView.findViewById(R.id.seekBarG);
        final SeekBar seekBar3 = (SeekBar) contentView.findViewById(R.id.seekBarB);
        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.1
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar4, int i4, boolean z) {
                textView.setText(String.valueOf(i4));
                ColorPopupWindow.this.changeColor(seekBar, seekBar2, seekBar3, imageView);
            }
        });
        seekBar2.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.2
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar4, int i4, boolean z) {
                textView2.setText(String.valueOf(i4));
                ColorPopupWindow.this.changeColor(seekBar, seekBar2, seekBar3, imageView);
            }
        });
        seekBar3.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.3
            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStartTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onStopTrackingTouch(SeekBar seekBar4) {
            }

            @Override // android.widget.SeekBar.OnSeekBarChangeListener
            public void onProgressChanged(SeekBar seekBar4, int i4, boolean z) {
                textView3.setText(String.valueOf(i4));
                ColorPopupWindow.this.changeColor(seekBar, seekBar2, seekBar3, imageView);
            }
        });
        View.OnClickListener onClickListener = new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.4
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                int color2 = ColorPopupWindow.getColor((ColorDrawable) ((Button) view2).getBackground());
                seekBar.setProgress((color2 >> 16) & 255);
                seekBar2.setProgress((color2 >> 8) & 255);
                seekBar3.setProgress((color2 >> 0) & 255);
            }
        };
        contentView.findViewById(R.id.buttonRed).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonPink).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonPurple).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonIndigo).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonBlue).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonLightBlue).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonCyan).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonTeal).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonGreen).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonLightGreen).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonLime).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonYellow).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonOrange).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonLightGray).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonGray).setOnClickListener(onClickListener);
        contentView.findViewById(R.id.buttonDarkGray).setOnClickListener(onClickListener);
        Button button = (Button) contentView.findViewById(R.id.buttonRDown);
        Button button2 = (Button) contentView.findViewById(R.id.buttonRUp);
        Button button3 = (Button) contentView.findViewById(R.id.buttonGDown);
        Button button4 = (Button) contentView.findViewById(R.id.buttonGUp);
        Button button5 = (Button) contentView.findViewById(R.id.buttonBDown);
        Button button6 = (Button) contentView.findViewById(R.id.buttonBUp);
        button.setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.5
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                seekBar.incrementProgressBy(-1);
            }
        });
        button2.setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.6
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                seekBar.incrementProgressBy(1);
            }
        });
        button3.setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.7
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                seekBar2.incrementProgressBy(-1);
            }
        });
        button4.setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.8
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                seekBar2.incrementProgressBy(1);
            }
        });
        button5.setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.9
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                seekBar3.incrementProgressBy(-1);
            }
        });
        button6.setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.10
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                seekBar3.incrementProgressBy(1);
            }
        });
        LongClickRepeatAdapter.bless(button);
        LongClickRepeatAdapter.bless(button2);
        LongClickRepeatAdapter.bless(button3);
        LongClickRepeatAdapter.bless(button4);
        LongClickRepeatAdapter.bless(button5);
        LongClickRepeatAdapter.bless(button6);
        ((Button) contentView.findViewById(R.id.buttonDone)).setOnClickListener(new View.OnClickListener() { // from class: com.tadaoyamaoka.vocalpitchmonitor.ColorPopupWindow.11
            @Override // android.view.View.OnClickListener
            public void onClick(View view2) {
                int parseInt = Integer.parseInt(textView.getText().toString());
                int parseInt2 = Integer.parseInt(textView2.getText().toString());
                imageButton.setImageDrawable(new ColorDrawable((parseInt << 16) | 0xFF000000 | (parseInt2 << 8) | Integer.parseInt(textView3.getText().toString())));
                ColorPopupWindow.this.dismiss();
            }
        });
        seekBar.setProgress(i);
        seekBar2.setProgress(i2);
        seekBar3.setProgress(i3);
        textView.setText(String.valueOf(i));
        textView2.setText(String.valueOf(i2));
        textView3.setText(String.valueOf(i3));
    }

    /* JADX INFO: Access modifiers changed from: private */
    public void changeColor(SeekBar seekBar, SeekBar seekBar2, SeekBar seekBar3, ImageView imageView) {
        int progress = seekBar.getProgress();
        int progress2 = seekBar2.getProgress();
        imageView.setBackgroundColor((progress << 16) | 0xFF000000 | (progress2 << 8) | seekBar3.getProgress());
    }

    public static int getColor(ColorDrawable colorDrawable) {
        Bitmap createBitmap = Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_4444);
        colorDrawable.draw(new Canvas(createBitmap));
        int pixel = createBitmap.getPixel(0, 0);
        createBitmap.recycle();
        return pixel;
    }
}
