{
  config,
  nixos-hardware,
  ...
}: {
  imports = [
    nixos-hardware.nixosModules.raspberry-pi-4
    ./kernel.nix
  ];

  uconsole.boot.configTxt = ''
    [pi3]
    kernel=u-boot-rpi3.bin

    [pi4]
    kernel=u-boot-rpi4.bin
    enable_gic=1
    armstub=armstub8-gic.bin

    # Otherwise the resolution will be weird in most cases, compared to
    # what the pi3 firmware does by default.
    disable_overscan=1

    # Supported in newer board revisions
    arm_boost=1

    [cm4]
    # Enable host mode on the 2711 built-in XHCI USB controller.
    # This line should be removed if the legacy DWC2 controller is required
    # (e.g. for USB device mode) or if USB support is not required.
    # otg_mode=1
    # ------------------------
    arm_boost=1
    max_framebuffers=2
    # dtoverlay=vc4-kms-v3d-pi4,cma-384
    # dtoverlay=uconsole,cm4
    # ------------------------

    [all]
    # Boot in 64-bit mode.
    arm_64bit=1

    # U-Boot needs this to work, regardless of whether UART is actually used or not.
    # Look in arch/arm/mach-bcm283x/Kconfig in the U-Boot tree to see if this is still
    # a requirement in the future.
    enable_uart=1

    # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
    # when attempting to show low-voltage or overtemperature warnings.
    avoid_warnings=1

    # ------------------------
    ignore_lcd=1
    disable_fw_kms_setup=1
    disable_audio_dither
    pwm_sample_bits=20

    # setup headphone detect pin
    gpio=10=ip,np

    dtoverlay=dwc2,dr_mode=host
    dtoverlay=audremap,pins_12_13
    dtparam=audio=on
    # dtparam=spi=on
    dtparam=ant2
    # ------------------------
  '';

  hardware.raspberry-pi."4".apply-overlays-dtmerge.enable = true;
  hardware.raspberry-pi."4".dwc2.enable = true;
  hardware.raspberry-pi."4".dwc2.dr_mode = "host";
  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays =
    [
      {
        name = "devterm-misc";
        filter = "bcm2711-rpi-cm4.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          /{
          compatible = "brcm,bcm2711";

          fragment@0 {
          target = <&i2c1>;
          __overlay__ {
            #address-cells = <1>;
            #size-cells = <0>;
            pinctrl-names = "default";
            pinctrl-0 = <&i2c1_pins>;
            status = "okay";

            adc101c: adc@54 {
              reg = <0x54>;
              compatible = "ti,adc101c";
              status = "okay";
            };
          };
          };

          fragment@1 {
          target = <&spi4>;
          __overlay__ {
            pinctrl-names = "default";
            pinctrl-0 = <&spi4_pins &spi4_cs_pins>;
            cs-gpios = <&gpio 4 1>;
            status = "okay";

            spidev4_0: spidev@0 {
              compatible = "spidev";
              reg = <0>;      /* CE0 */
              #address-cells = <1>;
              #size-cells = <0>;
              spi-max-frequency = <125000000>;
              status = "okay";
            };
          };
          };

          fragment@2 {
          target = <&uart1>;
          __overlay__ {
            pinctrl-names = "default";
            pinctrl-0 = <&uart1_pins>;
            status = "okay";
          };
          };

          fragment@3 {
          target = <&gpio>;
          __overlay__ {

            i2c1_pins: i2c1 {
              brcm,pins = <44 45>;
              brcm,function = <6>;
            };

            spi4_pins: spi4_pins {
              brcm,pins = <6 7>;
              brcm,function = <7>;
            };

            spi4_cs_pins: spi0_cs_pins {
              brcm,pins = <4>;
              brcm,function = <1>;
            };

            uart1_pins: uart1_pins {
              brcm,pins = <14 15>;
              brcm,function = <2>;
              brcm,pull = <0 2>;
            };

          };
          };

          fragment@4 {
          target-path = "/chosen";
          __overlay__ {
            bootargs = "8250.nr_uarts=1";
          };
          };

          };
        '';
      }

      {
        name = "devterm-panel-uc";
        filter = "bcm2711-rpi-cm4.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
          compatible = "brcm,bcm2711";

          fragment@0 {
          target=<&dsi1>;
          __overlay__ {
            #address-cells = <1>;
            #size-cells = <0>;
            status = "okay";

            port {
              dsi_out_port: endpoint {
                remote-endpoint = <&panel_dsi_port>;
              };
            };

            panel_cwu50: panel@0 {
              compatible = "clockwork,cwu50";
              reg = <0>;
              reset-gpio = <&gpio 8 1>;
              backlight = <&ocp8178_backlight>;
              rotation = <90>;

              port {
                panel_dsi_port: endpoint {
                  remote-endpoint = <&dsi_out_port>;
                };
              };
            };
          };
          };

          fragment@1 {
          target-path = "/";
          __overlay__  {
            ocp8178_backlight: backlight@0 {
              compatible = "ocp8178-backlight";
              backlight-control-gpios = <&gpio 9 0>;
              default-brightness = <5>;
            };
          };
          };

          };
        '';
      }
      {
        name = "devterm-pmu";
        filter = "bcm2711-rpi-cm4.dtb";
        dtsText = ''
          /dts-v1/;
          /plugin/;

          / {
          compatible = "brcm,bcm2711";

          fragment@0 {
          target = <&i2c0if>;
          __overlay__ {
            #address-cells = <1>;
            #size-cells = <0>;
            pinctrl-0 = <&i2c0_pins>;
            pinctrl-names = "default";
            status = "okay";

            axp22x: pmic@34 {
              interrupt-controller;
              #interrupt-cells = <1>;
              compatible = "x-powers,axp223";
              reg = <0x34>; /* i2c address */
              interrupt-parent = <&gpio>;
              interrupts = <2 8>;  /* IRQ_TYPE_EDGE_FALLING */
              irq-gpios = <&gpio 2 0>;

              regulators {

                x-powers,dcdc-freq = <3000>;

                reg_aldo1: aldo1 {
                  regulator-always-on;
                  regulator-min-microvolt = <3300000>;
                  regulator-max-microvolt = <3300000>;
                  regulator-name = "audio-vdd";
                };

                reg_aldo2: aldo2 {
                  regulator-always-on;
                  regulator-min-microvolt = <3300000>;
                  regulator-max-microvolt = <3300000>;
                  regulator-name = "display-vcc";
                };

                reg_dldo2: dldo2 {
                  regulator-always-on;
                  regulator-min-microvolt = <3300000>;
                  regulator-max-microvolt = <3300000>;
                  regulator-name = "dldo2";
                };

                reg_dldo3: dldo3 {
                  regulator-always-on;
                  regulator-min-microvolt = <3300000>;
                  regulator-max-microvolt = <3300000>;
                  regulator-name = "dldo3";
                };

                reg_dldo4: dldo4 {
                  regulator-always-on;
                  regulator-min-microvolt = <3300000>;
                  regulator-max-microvolt = <3300000>;
                  regulator-name = "dldo4";
                };

              };

              battery_power_supply: battery-power-supply {
                compatible = "x-powers,axp221-battery-power-supply";
                monitored-battery = <&battery>;
              };

              ac_power_supply: ac_power_supply {
                compatible = "x-powers,axp221-ac-power-supply";
              };

            };
          };
          };

          fragment@1 {
          target = <&i2c0if>;
          __overlay__ {
            compatible = "brcm,bcm2708-i2c";
          };
          };

          fragment@2 {
          target-path = "/aliases";
          __overlay__ {
            i2c0 = "/soc/i2c@7e205000";
          };
          };

          fragment@3 {
          target-path = "/";
          __overlay__  {
            battery: battery@0 {
              compatible = "simple-battery";
              constant-charge-current-max-microamp = <2100000>;
              voltage-min-design-microvolt = <3300000>;
            };
          };
          };

          };
        '';
      }
      # {
      #   name = "uconsole,cm4";
      #   dtsFile = ./uconsole-overlay.dts;
      #   filter = "bcm2711-rpi-cm4.dtb";
      # }
      {
        name = "vc4-kms-v3d-pi4,cma-384";
        dtboFile = "${config.boot.kernelPackages.kernel}/dtbs/overlays/vc4-kms-v3d-pi4.dtbo";
        filter = "bcm2711-rpi-cm4.dtb";
      }
      {
        name = "audremap,pins_12_13";
        dtboFile = "${config.boot.kernelPackages.kernel}/dtbs/overlays/audremap.dtbo";
        filter = "bcm2711-rpi-cm4.dtb";
      }
    ];
}
