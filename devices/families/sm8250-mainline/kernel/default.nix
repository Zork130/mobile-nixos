{ mobile-nixos
, fetchzip
, buildPackages
, ...
}:

let
  # Same tree and config as Nura's (postmarketOS) linux-postmarketos-qcom-sm8250 package.
  tag = "sm8250-7.2.0_git20261010";
in
mobile-nixos.kernel-builder {
  version = "7.2.0";
  configfile = ./config.aarch64;

  src = fetchzip {
    url = "https://gitlab.nura.eco/soc/qualcomm-sm8250/linux/-/archive/${tag}/linux-${tag}.tar.gz";
    hash = "sha256-7CYapSBytW0iuRJ+Wk6Vk7Y84mzM+MXI1mzk8pCfVg8=";
  };

  patches = [
    # OnePlus 8 Pro display (Samsung AMS678UW01), GPU and audio, by Timo (darknagel):
    # https://github.com/darknagel/oneplus-instantnoodlep-nura-unofficial (kernel-patches/)
    ./patches/0001-dt-bindings-display-panel-Add-Samsung-AMS678UW01.patch
    ./patches/0002-drm-panel-Add-Samsung-AMS678UW01-panel-driver.patch
    ./patches/0003-arm64-dts-qcom-sm8250-oneplus-instantnoodlep-Enable-.patch
    ./patches/0004-arm64-dts-qcom-sm8250-oneplus-instantnoodlep-Enable-.patch
    ./patches/0005-arm64-dts-qcom-sm8250-oneplus-instantnoodlep-Enable-.patch
    # Speaker amplifiers: vendor TFA9874 init, DC-DC setup fixes, boost config.
    ./patches/0006-ASoC-tfa987x-apply-TFA9874-init-and-enable-the-boost.patch
    # q6core/q6afe: custom topologies + module params, for TFADSP speaker protection.
    ./patches/0007-ASoC-qcom-q6core-q6afe-custom-topologies-and-module-params.patch
    # Speaker current sense feedback on TERTIARY_MI2S_TX (amps, machine driver, DT).
    ./patches/0008-ASoC-sm8250-oneplus-instantnoodlep-speaker-current-sense-feedback.patch
    # Tertiary MI2S (speakers) at 2 x 32 bit slots, for current sense resolution.
    ./patches/0009-ASoC-sm8250-tfa987x-32-bit-slots-on-tertiary-MI2S.patch
  ];

  # drm/msm generates its register headers with python at build time.
  nativeBuildInputs = [ buildPackages.python3 ];

  isModular = true;
  isCompressed = "gz";
}
