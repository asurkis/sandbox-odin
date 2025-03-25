package main

import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"

main :: proc() {
	assert(sdl.Init({.VIDEO} | {.EVENTS}))
	defer sdl.Quit()

	window := sdl.CreateWindow("Main window", 1280, 720, sdl.WINDOW_RESIZABLE)
	assert(window != nil)
	defer sdl.DestroyWindow(window)

	device := sdl.CreateGPUDevice({.SPIRV}, true, nil)
	assert(device != nil)
	defer sdl.DestroyGPUDevice(device)

	assert(sdl.ClaimWindowForGPUDevice(device, window))
	defer sdl.ReleaseWindowFromGPUDevice(device, window)

	/*
	vs_code := make([dynamic]byte, 0)
	vs_code_len: uint = len(vs_code)
	defer delete(vs_code)

	vs_create_info := sdl.GPUShaderCreateInfo {
		code_size            = vs_code_len, /**< The size in bytes of the code pointed to. */
		code                 = &vs_code[0], /**< A pointer to shader code. */
		entrypoint           = "main", /**< A pointer to a null-terminated UTF-8 string specifying the entry point function name for the shader. */
		format               = {.SPIRV}, /**< The format of the shader code. */
		stage                = .VERTEX, /**< The stage the shader program corresponds to. */
		num_samplers         = 0, /**< The number of samplers defined in the shader. */
		num_storage_textures = 0, /**< The number of storage textures defined in the shader. */
		num_storage_buffers  = 0, /**< The number of storage buffers defined in the shader. */
		num_uniform_buffers  = 0, /**< The number of uniform buffers defined in the shader. */
		props                = 0, /**< A properties ID for extensions. Should be 0 if no extensions are needed. */
	}

	vertex_shader := sdl.CreateGPUShader(device, vs_create_info)
	defer sdl.ReleaseGPUShader(device, vertex_shader)
	*/

	main_loop: for {
		for evt: sdl.Event; sdl.PollEvent(&evt); {
			#partial switch evt.type {
			case .QUIT, .WINDOW_CLOSE_REQUESTED:
				break main_loop
			case .KEY_DOWN:
				if evt.key.key == sdl.K_ESCAPE do break main_loop
			}
		}

		command_buffer := sdl.AcquireGPUCommandBuffer(device)
		assert(command_buffer != nil)
		defer assert(sdl.SubmitGPUCommandBuffer(command_buffer))

		swapchain_texture: ^sdl.GPUTexture
		swapchain_texture_width, swapchain_texture_height: u32
		assert(
			sdl.WaitAndAcquireGPUSwapchainTexture(
				command_buffer,
				window,
				&swapchain_texture,
				&swapchain_texture_width,
				&swapchain_texture_height,
			),
		)
		color_target_infos := [?]sdl.GPUColorTargetInfo {
			{
				texture               = swapchain_texture, /**< The texture that will be used as a color target by a render pass. */
				mip_level             = 0, /**< The mip level to use as a color target. */
				layer_or_depth_plane  = 0, /**< The layer index or depth plane to use as a color target. This value is treated as a layer index on 2D array and cube textures, and as a depth plane on 3D textures. */
				clear_color           = {
					0,
					1,
					1,
					0,
				}, /**< The color to clear the color target to at the start of the render pass. Ignored if GPU_LOADOP_CLEAR is not used. */
				load_op               = .CLEAR, /**< What is done with the contents of the color target at the beginning of the render pass. */
				store_op              = .STORE, /**< What is done with the results of the render pass. */
				resolve_texture       = nil, /**< The texture that will receive the results of a multisample resolve operation. Ignored if a RESOLVE* store_op is not used. */
				resolve_mip_level     = 0, /**< The mip level of the resolve texture to use for the resolve operation. Ignored if a RESOLVE* store_op is not used. */
				resolve_layer         = 0, /**< The layer index of the resolve texture to use for the resolve operation. Ignored if a RESOLVE* store_op is not used. */
				cycle                 = false, /**< true cycles the texture if the texture is bound and load_op is not LOAD */
				cycle_resolve_texture = false, /**< true cycles the resolve texture if the resolve texture is bound. Ignored if a RESOLVE* store_op is not used. */
			},
		}
		render_pass := sdl.BeginGPURenderPass(
			command_buffer,
			&color_target_infos[0],
			len(color_target_infos),
			nil,
		)
		assert(render_pass != nil)
		defer sdl.EndGPURenderPass(render_pass)
	}
}
