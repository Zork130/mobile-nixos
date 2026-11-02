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

  mobile.system.android.device_name = "OnePlus8Pro";
  # Launched with Android 10: A/B, but with discrete recovery_a/recovery_b
  # partitions, and the bootloader never passes skip_initramfs.
  mobile.system.android.boot_as_recovery = false;
}
