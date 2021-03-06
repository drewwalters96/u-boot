#!/bin/sh
#
# script to generate FIT image source for 64-bit sunxi boards with ARM Trusted
# Firmware, SCP firmware, and multiple device trees (given on the command line)
#
# usage: $0 <dt_name> [<dt_name> ...]

[ -z "$BL31" ] && BL31="bl31.bin"
[ -z "$SCP" ] && SCP="scp.bin"

if [ ! -f "$BL31" ]; then
	echo "WARNING: BL31 file $BL31 NOT found, resulting binary is non-functional" >&2
	echo "Please read the section on ARM Trusted Firmware (ATF) in board/sunxi/README.sunxi64" >&2
	BL31=/dev/null
fi

cat << __HEADER_EOF
/dts-v1/;

/ {
	description = "Configuration to load ATF and SCP before U-Boot";
	#address-cells = <1>;

	images {
		uboot {
			description = "U-Boot (64-bit)";
			data = /incbin/("u-boot-nodtb.bin");
			type = "standalone";
			arch = "arm64";
			os = "u-boot";
			compression = "none";
			load = <0x4a000000>;
		};
		atf {
			description = "ARM Trusted Firmware";
			data = /incbin/("$BL31");
			type = "firmware";
			arch = "arm64";
			os = "arm-trusted-firmware";
			compression = "none";
			load = <0x4c000>;
			entry = <0x4c000>;
		};
__HEADER_EOF

if [ -f "$SCP" ]; then
	cat << __SCP_EOF
		scp {
			description = "SCP Firmware";
			data = /incbin/("$SCP");
			type = "firmware";
			arch = "or1k";
			compression = "none";
			load = <0x40000>;
		};
__SCP_EOF
fi

cnt=1
for dtname
do
	cat << __FDT_IMAGE_EOF
		fdt@$cnt {
			description = "$(basename $dtname .dtb)";
			data = /incbin/("$dtname");
			type = "flat_dt";
			compression = "none";
		};
__FDT_IMAGE_EOF
	cnt=$((cnt+1))
done

cat << __CONF_HEADER_EOF
	};
	configurations {
		default = "config@1";

__CONF_HEADER_EOF

if [ -f "$SCP" ]; then
	LOADABLES='"uboot", "scp"'
else
	LOADABLES='"uboot"'
fi

cnt=1
for dtname
do
	cat << __CONF_SECTION_EOF
		config@$cnt {
			description = "$(basename $dtname .dtb)";
			firmware = "atf";
			loadables = $LOADABLES;
			fdt = "fdt@$cnt";
		};
__CONF_SECTION_EOF
	cnt=$((cnt+1))
done

cat << __FOOTER_EOF
	};
};
__FOOTER_EOF
