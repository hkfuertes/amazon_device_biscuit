#!/system/bin/sh

# Biscuit TLV320 speaker baseline.
# The HAL turns the external speaker amp on only while audio is written.
mix() {
    tinymix "$@" >/dev/null 2>&1 || true
}

mix "HPL Output Mixer L_DAC Switch" 1
mix "HPR Output Mixer R_DAC Switch" 1
mix "Audio_DacMux_Setting" Off
mix "Right Channel Only" On
mix "HP Driver Gain Volume" 6 6
mix "MFP Gpio Mute" 0
mix "Ext_Speaker_Amp_Switch" Off
mix "Audio_Amp_R_Switch" Off
mix "Audio_Amp_L_Switch" Off
