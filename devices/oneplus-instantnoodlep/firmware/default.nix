{ lib
, buildPackages
, fetchFromGitHub
, fetchurl
, runCommand
}:

# Mirrors Nura's (postmarketOS) firmware-oneplus-instantnoodlep package.

let
  # Tools run during the build, so they are built for the build platform.
  pil-squasher = buildPackages.stdenv.mkDerivation {
    pname = "pil-squasher";
    version = "unstable-2024";
    src = fetchFromGitHub {
      owner = "linux-msm";
      repo = "pil-squasher";
      rev = "3c9f8b8756ba6e4dbf9958570fd4c9aea7a70cf4";
      hash = "sha256-MEW85w3RQhY3tPaWtH7OO22VKZrjwYUWBWnF3IF4YC0=";
    };
    makeFlags = [ "prefix=${placeholder "out"}" ];
  };

  qca-swiss-army-knife = fetchFromGitHub {
    owner = "qca";
    repo = "qca-swiss-army-knife";
    rev = "6df4dae3e2f5e4c2903f3cafd40996fc1b3639ce";
    hash = "sha256-FFoV58YVK7KGBw/JPFWcvGkJOONrfKCvACprYCzIKeg=";
  };

  baseFw = fetchFromGitHub {
    owner = "pangwalla";
    repo = "oneplus-instantnoodlep-firmware";
    rev = "2dce2681689fcf615198c663555c5a7c7b3650ba";
    hash = "sha256-JjKQGJXEkUe1uq/bDaTqFGyAelnicfefY3zRqo4HJmw=";
  };

  # Speaker ACDB from the stock firmware: holds the AFE module parameters for
  # the NXP TFADSP speaker protection on the ADSP.
  speakerAcdb = fetchurl {
    url = "https://raw.githubusercontent.com/TheMuppets/proprietary_vendor_oneplus_instantnoodlep/c12a066140bb63eb32a52cb3746fb1809dae7683/proprietary/odm/etc/acdbdata/Speaker_cal.acdb";
    sha256 = "1lfcglsdhhjsrn14wff9llmdbczb31klpfa843fcbc3293m443rp";
  };
in runCommand "oneplus-instantnoodlep-firmware" {
  nativeBuildInputs = [ pil-squasher buildPackages.python3 ];
  # We make no claims that it can be redistributed.
  meta.license = lib.licenses.unfree;
} ''
  fw=$out/lib/firmware
  mkdir -p $fw/postmarketos $fw/qca $fw/qcom/sdx55m $fw/ath11k/QCA6390/hw2.0
  cp -r ${baseFw} src
  chmod -R +w src
  cd src

  # The device tree asks for "postmarketos/<name>.mbn"
  for f in adsp/adsp cdsp/cdsp ipa/ipa_fws ipa/ipa_uc slpi/slpi venus/venus; do
    pil-squasher $fw/postmarketos/$(basename $f).mbn $f.mdt
  done

  cp bluetooth/* $fw/qca/
  # a650_sqe.fw / a650_gmu.bin from the device are too old for current kernels
  # ("SQE ucode is too old. Have version 93 need at least 95"); they aren't
  # device-signed, so leave them to linux-firmware.
  cp gpu/a650_zap.* $fw/qcom/
  # Device-signed zap shader, where the device tree looks for it.
  mkdir -p $fw/qcom/sm8250/OnePlus/instantnoodlep
  pil-squasher $fw/qcom/sm8250/OnePlus/instantnoodlep/a650_zap.mbn gpu/a650_zap.mdt
  cp modem/* $fw/qcom/sdx55m/

  # AFE calibration for qcom,cal-firmware: speaker (ACDB id 15) and its V/I
  # feedback (ACDB id 102), at 48 kHz.
  python3 ${./acdb-afe-cal.py} ${speakerAcdb} 15 48000 \
    $fw/qcom/sm8250/OnePlus/instantnoodlep/afe-cal-speaker.bin
  python3 ${./acdb-afe-cal.py} ${speakerAcdb} 102 48000 \
    $fw/qcom/sm8250/OnePlus/instantnoodlep/afe-cal-speaker-vi.bin

  (
    cd wlan
    python3 ${qca-swiss-army-knife}/tools/scripts/ath11k/ath11k-bdencoder -c board-2.json
    cp board-2.bin amss.bin m3.bin $fw/ath11k/QCA6390/hw2.0/
  )
''
