bfulist = open("bfu_list.txt", "r")
bfu_dict = {}

state = 0
for line in bfulist:
	if state == 0:
		# wait for bfu module name
		bfu_name = line.strip()
		bfu_dict[bfu_name] = []
		state = 1
	elif state == 1:
		# wait for {
		if (line[0] == '{'):
			state = 2
	elif state == 2:
		#ports
		if (line[0] == '}'):
			state = 0
		else:
			bfu_dict[bfu_name].append(line.strip())

bfulist.close()

# print(bfu_dict)

with open("primate.template") as f_old, open("primate.scala", "w") as f_new:
	for line in f_old:
		if '#BFU_INSTANTIATE#' in line:
			for bfu_name in bfu_dict:
				f_new.write("  val " + bfu_name + "Port = Module(new " + bfu_name + "(NUM_THREADS_LG, REG_WIDTH, NUM_FUOPS_LG, NUM_THREADS))\n")
		elif '#BFU_INPUT#' in line:
			i = 0
			for bfu_name in bfu_dict:
				for port_name in bfu_dict[bfu_name]:
					f_new.write("  if(FU_PERF_COUNTERS){\n")
					f_new.write("    perfC.io.bfuActive(" + str(i) + ") := (fuFifos(" + str(i) + ").io.deq.valid) || (!" + bfu_name + "Port." + port_name + ".in_ready) \n")
					f_new.write("  }\n")
					f_new.write("  when (fuFifos(" + str(i) + ").io.deq.valid && " + bfu_name + "Port." + port_name + ".in_ready) {\n")
					f_new.write("    val deq = fuFifos(" + str(i) + ").io.deq\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_valid := true.B\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_tag := deq.bits.tag\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_opcode := deq.bits.opcode\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_bits := deq.bits.bits\n")
					f_new.write("    fuFifos(" + str(i) + ").io.deq.ready := true.B\n")
					f_new.write("  } .otherwise {\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_valid := false.B\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_tag := DontCare\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_opcode := DontCare\n")
					f_new.write("    " + bfu_name + "Port." + port_name + ".in_bits := DontCare\n")
					f_new.write("    fuFifos(" + str(i) + ").io.deq.ready := false.B\n")
					f_new.write("  }\n")
					i += 1
		elif '#BFU_OUTPUT#' in line:
			i = 0
			for bfu_name in bfu_dict:
				for port_name in bfu_dict[bfu_name]:
					f_new.write("  " + bfu_name + "Port." + port_name + ".out_ready := true.B\n")
					f_new.write("  when (" + bfu_name + "Port." + port_name + ".out_valid) {\n")
					f_new.write("    val destMem_in = Wire(new DestMemT)\n")
					f_new.write("    destMem_in.slctFU := " + bfu_name + "Port." + port_name + ".out_flag\n")
					f_new.write("    destMem_in.dest := " + bfu_name + "Port." + port_name + ".out_bits\n")
					f_new.write("    destMem_in.wben := Fill(NUM_REGBLOCKS, 1.U)\n")
					f_new.write("    destMems(" + str(i) + ").io.wren := true.B\n")
					f_new.write("    destMems(" + str(i) + ").io.wraddress := " + bfu_name + "Port." + port_name + ".out_tag\n")
					f_new.write("    destMems(" + str(i) + ").io.data := destMem_in.asUInt\n")
					f_new.write("    threadStates(" + bfu_name + "Port." + port_name + ".out_tag).execValids(" + str(i) + ") := true.B\n")
					f_new.write("  }\n")

		else:
			f_new.write(line)