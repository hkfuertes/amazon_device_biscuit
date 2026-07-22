package com.amazon.biscuit.service;

interface IBiscuitService {
    boolean play(String name);
    boolean setFrame(String rgbHex72);
    boolean setVolume(int current, int max);
    boolean setMicMuted(boolean muted);
    boolean clear();
    String status();
}
