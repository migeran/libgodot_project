#include <stdlib.h>
#include <stdio.h>
#include <dlfcn.h>
#include <string>
#include <vector>

#include <libgodot.h>

#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/godot_instance.hpp>


#ifdef __APPLE__
#define LIBGODOT_LIBRARY_NAME "libgodot.dylib"
#else
#define LIBGODOT_LIBRARY_NAME "./libgodot.so"
#endif

extern "C" {

static void initialize_default_module(godot::ModuleInitializationLevel p_level) {
    if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }

}

static void uninitialize_default_module(godot::ModuleInitializationLevel p_level) {
    if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
        return;
    }
}

GDExtensionBool GDE_EXPORT gdextension_default_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
    godot::GDExtensionBinding::InitObject init_object(p_get_proc_address, p_library, r_initialization);

    init_object.register_initializer(initialize_default_module);
    init_object.register_terminator(uninitialize_default_module);
    init_object.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);

    return init_object.init();
}

}

class LibGodot {
public:
    LibGodot(std::string p_path = LIBGODOT_LIBRARY_NAME) {
        handle = dlopen(p_path.c_str(), RTLD_LAZY);
        if (handle == nullptr) {
            fprintf(stderr, "Error opening libgodot: %s\n", dlerror());
            return;
        }
        *(void**)(&func_libgodot_create_godot_instance) = dlsym(handle, "libgodot_create_godot_instance");
        if (func_libgodot_create_godot_instance == nullptr) {
            fprintf(stderr, "Error acquiring function: %s\n", dlerror());
            dlclose(handle);
            handle == nullptr;
            return;
        }
        *(void**)(&func_libgodot_destroy_godot_instance) = dlsym(handle, "libgodot_destroy_godot_instance");
        if (func_libgodot_destroy_godot_instance == nullptr) {
            fprintf(stderr, "Error acquiring function: %s\n", dlerror());
            dlclose(handle);
            handle == nullptr;
            return;
        }
    }

    ~LibGodot() {
        if (is_open()) {
            dlclose(handle);
        }
    }

    bool is_open() {
        return handle != nullptr && func_libgodot_create_godot_instance != nullptr;
    }

    godot::GodotInstance *create_godot_instance(int p_argc, char *p_argv[], GDExtensionInitializationFunction p_init_func = gdextension_default_init) {
        if (!is_open()) {
            return nullptr;
        }
        GDExtensionObjectPtr instance = func_libgodot_create_godot_instance(p_argc, p_argv, p_init_func);
        if (instance == nullptr) {
            return nullptr;
        }
        return reinterpret_cast<godot::GodotInstance *>(godot::internal::get_object_instance_binding(instance));
    }

    void destroy_godot_instance(godot::GodotInstance* instance) {
        GDExtensionObjectPtr obj = godot::internal::gdextension_interface_object_get_instance_from_id(instance->get_instance_id());
        func_libgodot_destroy_godot_instance(obj);
    }

private:
    void *handle = nullptr;
    GDExtensionObjectPtr (*func_libgodot_create_godot_instance)(int, char *[], GDExtensionInitializationFunction) = nullptr;
    void (*func_libgodot_destroy_godot_instance)(GDExtensionObjectPtr) = nullptr;
};

int main(int argc, char **argv) {

    LibGodot libgodot;

    std::string program;
    if (argc > 0) {
        program = std::string(argv[0]);
    }
    std::vector<std::string> args = { program, "--path", "../../project/", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3" };

    std::vector<char*> argvs;
    for (const auto& arg : args) {
        argvs.push_back((char*)arg.data());
    }
    argvs.push_back(nullptr);

    godot::GodotInstance *instance = libgodot.create_godot_instance(argvs.size(), argvs.data());
    if (instance == nullptr) {
        fprintf(stderr, "Error creating Godot instance\n");
        return EXIT_FAILURE;
    }

    instance->start();
    while (!instance->iteration()) {}
    libgodot.destroy_godot_instance(instance);

    return EXIT_SUCCESS;
}