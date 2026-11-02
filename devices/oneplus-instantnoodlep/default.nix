{ config, lib, pkgs, ... }:

{
  imports = [
    ../families/sm8250-mainline
  ];

  mobile.device.name = "oneplus-instantnoodlep";
  mobile.device.identity = {
    name = "OnePlus 8 Pro";
    manufacturer = "OnePlus";
  };
  mobile.device.supportLevel = "unsupported";

  mobile.hardware = {
    ram = 1024 * 8;
    screen = {
      width = 1440; height = 3168;
    };
  };

  mobile.device.firmware = pkgs.callPackage ./firmware {};

  mobile.boot.stage-1.kernel.modules = [
    # Touchscreen, so the stage-1 boot menu is usable.
    "s6sy761"
    # The bootloader framebuffer stops updating once dispcc probes, so the
    # real panel has to come up in stage-1 or stage-1 is invisible.
    "panel_samsung_ams678uw01"
  ];

  # msm brings the GPU up when it binds, which now happens in stage-1.
  mobile.boot.stage-1.firmware = [
    (pkgs.runCommand "oneplus-instantnoodlep-initrd-gpu-firmware" {} ''
      mkdir -p $out/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep
      cp ${pkgs.linux-firmware}/lib/firmware/qcom/{a650_sqe.fw,a650_gmu.bin} $out/lib/firmware/qcom/
      cp ${config.mobile.device.firmware}/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/a650_zap.mbn \
        $out/lib/firmware/qcom/sm8250/OnePlus/instantnoodlep/
    '')
  ];

  # ALSA UCM for the "OnePlus 8 Pro" sm8250 card (speakers + digital mics).
  mobile.quirks.audio.alsa-ucm-meld = true;
  environment.systemPackages = [
    (pkgs.runCommand "oneplus-instantnoodlep-alsa-ucm" { } ''
      install -Dm644 ${./ucm/OnePlus8Pro.conf} "$out/share/alsa/ucm2/conf.d/sm8250/OnePlus 8 Pro.conf"
      install -Dm644 ${./ucm/HiFi.conf} $out/share/alsa/ucm2/OnePlus8Pro/HiFi.conf
    '')
  ];

  # The capture PCM advertises S24_LE but the samples aren't laid out that way:
  # PipeWire's S24 conversion turns them into clipped noise (8 effective bits),
  # while S16_LE captures cleanly.
  services.pipewire.wireplumber.extraConfig."51-oneplus8pro-mic-s16" = {
    "monitor.alsa.rules" = [
      {
        matches = [ { "node.name" = "alsa_input.platform-sound.HiFi__Mic__source"; } ];
        actions.update-props."audio.format" = "S16LE";
      }
    ];
  };

  # The TFA9874 speaker protection DSP isn't used on mainline, and with it goes
  # the loudness Android gets from its compressor. Stand in with makeup gain
  # and a lookahead limiter, as the default "Speaker" output.
  services.pipewire.extraConfig.pipewire."60-oneplus8pro-speaker-loudness" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Speaker";
          "media.name" = "Speaker loudness";
          "filter.graph" = {
            nodes = [
              {
                type = "ladspa";
                name = "limiter";
                plugin = "${pkgs.ladspaPlugins}/lib/ladspa/fast_lookahead_limiter_1913.so";
                label = "fastLookaheadLimiter";
                control = {
                  "Input gain (dB)" = 8;
                  "Limit (dB)" = -1;
                  "Release time (s)" = 0.1;
                };
              }
            ];
            inputs = [ "limiter:Input 1" "limiter:Input 2" ];
            outputs = [ "limiter:Output 1" "limiter:Output 2" ];
          };
          "audio.channels" = 2;
          "audio.position" = [ "FL" "FR" ];
          "capture.props" = {
            "node.name" = "effect_input.speaker_loudness";
            "media.class" = "Audio/Sink";
            "priority.session" = 2000;
          };
          "playback.props" = {
            "node.name" = "effect_output.speaker_loudness";
            "node.passive" = true;
            "target.object" = "alsa_output.platform-sound.HiFi__Speaker__sink";
          };
        };
      }
    ];
  };

  mobile.system.android.device_name = "OnePlus8Pro";
  # Launched with Android 10: A/B, but with discrete recovery_a/recovery_b
  # partitions, and the bootloader never passes skip_initramfs.
  mobile.system.android.boot_as_recovery = false;
}
