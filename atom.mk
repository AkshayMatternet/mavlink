

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_HOST_MODULE := mavgen

mavgen_files := \
	$(call all-files-under,pymavlink,.py) \
	$(call all-files-under,pymavlink,.xsd) \
	$(call all-files-under,pymavlink,.h) \
	$(call all-files-under,message_definitions,.xml)

# Install files in host staging directory
LOCAL_COPY_FILES := \
	$(foreach __f,$(mavgen_files), \
		$(__f):$(HOST_OUT_STAGING)/usr/lib/mavgen/$(__f) \
	)

# Needed to force a build order of LOCAL_COPY_FILES
LOCAL_EXPORT_PREREQUISITES := \
	$(foreach __f,$(mavgen_files), \
		$(HOST_OUT_STAGING)/usr/lib/mavgen/$(__f) \
	)

include $(BUILD_CUSTOM)

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
## Note : rules shoud NOT use any variables defined in the context of the
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
$$(mavgen_done_file): PRIVATE_OUT_DIR := $$(mavgen_out_dir)
$$(mavgen_done_file): $$(mavgen_xml_file)
	@echo "$$(PRIVATE_MODULE): Generating mavlink files from $$(call path-from-top,$3)"
	$(Q) cd $(HOST_OUT_STAGING)/usr/lib/mavgen && python -m pymavlink.tools.mavgen \
		--lang $1 -o $$(PRIVATE_OUT_DIR) $3
	@mkdir -p $(TARGET_OUT_STAGING)/usr/share/mavlink
	$(Q) cp -af $3 $(TARGET_OUT_STAGING)/usr/share/mavlink/$(notdir $3).$$(PRIVATE_MODULE)
	$(Q) mv -f $(TARGET_OUT_STAGING)/usr/share/mavlink/$(notdir $3).$$(PRIVATE_MODULE) \
		$(TARGET_OUT_STAGING)/usr/share/mavlink/$(notdir $3)
	@mkdir -p $$(dir $$@)
	@:>$$(mavgen_dep_file)
	@for header in $$$$(find $$(PRIVATE_OUT_DIR) -name '*.h'); do \
		echo "$$$${header}: $$(mavgen_done_file)" >> $$(mavgen_dep_file); \
		echo -e "\t@:" >> $$(mavgen_dep_file); \
	done
	@touch $$@
-include $$(mavgen_dep_file)

# Update alchemy variables for the module
LOCAL_CLEAN_FILES += $$(mavgen_done_file) $$(mavgen_dep_file)
LOCAL_PREREQUISITES += $$(mavgen_xml_file)
LOCAL_EXPORT_PREREQUISITES += $$(mavgen_gen_files) $$(mavgen_done_file)
LOCAL_CUSTOM_TARGETS += $$(mavgen_done_file)
LOCAL_DEPENDS_HOST_MODULES += host.mavgen

endef

# Register the macro in alchemy
$(call local-register-custom-macro,mavgen-macro)
