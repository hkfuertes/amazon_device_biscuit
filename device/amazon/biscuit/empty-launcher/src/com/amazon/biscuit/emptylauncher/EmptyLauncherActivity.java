package com.amazon.biscuit.emptylauncher;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;

public final class EmptyLauncherActivity extends Activity {
    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        View black = new View(this);
        black.setBackgroundColor(0xff000000);
        setContentView(black);
    }
}
