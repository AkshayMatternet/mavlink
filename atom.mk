LOCAL_PATH := $(call my-dir)

###############################################################################
## Custom macro that can be used in LOCAL_CUSTOM_MACROS of a module to
## create automatically rules to generate files from xml.
## Note : in the context of the macro, LOCAL_XXX variables refer to the module
## that use the macro, not this module defining the macro.
## As the content of the macro is 'eval' after, most of variable ref shall be
## escaped (hence the $$). Only $1, $2... variables can be used directly.
## Note : no 'global' variable shall be used except the ones defined by
## alchemy (TARGET_XXX and HOST_XXX variables). Otherwise the macro will no
## work when integrated in a SDK (using local-register-custom-macro).
## Note : rules should NOT use any variables defined in the context of the
## macro (for the same reason PRIVATE_XXX variables shall be used in place of
## LOCAL_XXX variables).
## Note : if you need a script or a binary, please install it in host staging
## directory and execute it from there. This way it will also work in the
## context of a SDK.
###############################################################################

# Before mavgen is installed, we need it during makefile parsing phase
# We define this variable to find it in $(LOCAL_PATH) if not found yet in
# host staging directory
mavgen-macro-path := $(LOCAL_PATH)

# $1: language (C)
# $2: output directory (Relative to build directory unless an absolute path is
#     given (ex LOCAL_PATH).
# $3: input xml file

define mavgen-macro

# Setup some internal variables
mavgen_xml_file := $3
mavgen_module_build_dir := $(call local-get-build-dir)
mavgen_out_dir := $(if $(call is-path-absolute,$2),$2,$$(mavgen_module_build_dir)/$2)
mavgen_done_file := $$(mavgen_module_build_dir)/$$(notdir $$(mavgen_xml_file)).done
mavgen_dep_file := $$(mavgen_module_build_dir)/$$(notdir $$(mavgen_xml_file)).d

# Actual generation rule
# The copy of xml is staging is done in 2 steps because several modules could use
# the same xml the move ensure atomicity of the copy.
$$(mavgen_done_file): PRIVATE_OUT_DIR := $$(mavgen_out_dir)/mavlink
$$(mavgen_done_file): PRIVATE_DEP_FILE := $$(mavgen_dep_file)
$$(mavgen_done_file): $$(mavgen_xml_file)
	@echo "$$(PRIVATE_MODULE): Generating mavlink files from $$(call path-from-top,$3)"
	$(Q) cd $(HOST_OUT_STAGING)/usr/lib/mavgen && python -m pymavlink.tools.mavgen \
		--lang $1 -o $$(PRIVATE_OUT_DIR) $3
	@mkdir -p $(TARGET_OUT_STAGING)/usr/share/mavlink
	$(Q) cp -af $3 $(TARGET_OUT_STAGING)/usr/share/mavlink/$(notdir $3).$$(PRIVATE_MODULE)
	$(Q) mv -f $(TARGET_OUT_STAGING)/usr/share/mavlink/$(notdir $3).$$(PRIVATE_MODULE) \
		$(TARGET_OUT_STAGING)/usr/share/mavlink/$(notdir $3)
	@mkdir -p $$(dir $$@)
	@:>$$(PRIVATE_DEP_FILE)
	@for header in $$$$(find $$(PRIVATE_OUT_DIR) -name '*.h'); do \
		echo "$$$${header}: $$@" >> $$(PRIVATE_DEP_FILE); \
		echo -e "\t@:" >> $$(PRIVATE_DEP_FILE); \
	done
	@touch $$@
	@mkdir -p $(TARGET_OUT_BUILD)/mavlink/wireshark/plugins
	$(Q) cd $(HOST_OUT_STAGING)/usr/lib/mavgen && python -m pymavlink.tools.mavgen --lang=WLua \
		-o $(TARGET_OUT_BUILD)/mavlink/wireshark/plugins/mymavlink.lua $3
-include $$(mavgen_dep_file)

# Update alchemy variables for the module
LOCAL_CLEAN_FILES += $$(mavgen_done_file) $$(mavgen_dep_file)
LOCAL_EXPORT_PREREQUISITES += $$(mavgen_done_file)
LOCAL_CUSTOM_TARGETS += $$(mavgen_done_file)
LOCAL_DEPENDS_HOST_MODULES += host.mavgen host.mavlink-common-xml
LOCAL_C_INCLUDES += $$(mavgen_out_dir)

endef

# Register the macro in alchemy
$(call local-register-custom-macro,mavgen-macro)

include $(CLEAR_VARS)

LOCAL_MODULE := apm-mavlink-ardupilotmega
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
LOCAL_DESCRIPTION := Mavlink generated files for boards using the ardupilotmega\
	messages definition
LOCAL_CATEGORY_PATH := apm

MAVLINK_APM_ARDUPILOTMEGA_BUILD_DIR := $(call local-get-build-dir)

LOCAL_DEPENDS_HOST_MODULES := host.mavgen

LOCAL_EXPORT_C_INCLUDES := \
	$(MAVLINK_APM_ARDUPILOTMEGA_BUILD_DIR) \
	$(MAVLINK_APM_ARDUPILOTMEGA_BUILD_DIR)/GCS_MAVLink/

# Make sure the -C parameter come after
# $(LINUX_MAKE_ARGS) to override default value
$(MAVLINK_APM_ARDUPILOTMEGA_BUILD_DIR)/$(LOCAL_MODULE_FILENAME):$(LOCAL_PATH)/message_definitions/v1.0/ardupilotmega.xml
	@echo "Generating mavlink files for APM:plane ardupilotmega"
	$(Q) PYTHON_PATH=$(HOST_OUT_STAGING)/usr/lib/mavgen && \
		$(HOST_OUT_STAGING)/usr/lib/mavgen/pymavlink/tools/mavgen.py \
		--lang=C --wire-protocol=2.0 \
		--output=$(MAVLINK_APM_ARDUPILOTMEGA_BUILD_DIR)/GCS_MAVLink/include/mavlink/v2.0/ \
		$<
	@touch $@

include $(BUILD_CUSTOM)


include $(CLEAR_VARS)

LOCAL_HOST_MODULE := mavlink-common-xml
LOCAL_DESCRIPTION := common xml files used by platform specific mavlink xmls
LOCAL_CATEGORY_PATH := mavlink

mavlink_common_xml_files := \
	$(call all-files-under,message_definitions,.xml)

LOCAL_COPY_FILES := \
	$(foreach __f,$(mavlink_common_xml_files), \
		$(__f):$(HOST_OUT_STAGING)/usr/lib/mavgen/$(__f) \
	)

include $(BUILD_CUSTOM)
