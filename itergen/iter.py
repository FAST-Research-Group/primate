import os
import sys
import argparse
import logging
import glob
import random

DEBUG_SKIP_SCRIPTS = True

SCRIPT_DIR 		= os.path.dirname(os.path.realpath(__file__))	#The real, on disk location of the file of the script
SCRIPT_RUN_DIR	= os.getcwd()									#Where the working directory of the script is


#TODO, modify target in .sh files using this value
TARGET			= "pkt_reassembly_tail"

APP_PATH		= "primate-uarch/apps/pktReassembly"
EMULATOR_PATH	= "primate-uarch/chisel/Gorilla++/emulator"

OUT_VCD 	 	= "primate-uarch/chisel/Gorilla++/test_run_dir/"

tuneable 		= ["NUM_THREADS","NUM_ALUS","NUM_BFUS"]
#NUM_FUS is just NUM_ALUS + NUM_BFUS
default_settings= {"NUM_THREADS":16, "NUM_ALUS":2, "NUM_BFUS":3, "NUM_FUS":5} #TODO read from file instead of given
next_settings	= {"NUM_THREADS":16, "NUM_ALUS":2, "NUM_BFUS":3, "NUM_FUS":5}
test_settings 	= []
test_results 	= []

#Parses arguments at script initialization, produces an args object
def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser( 
					description = 'Tries to tune paramaters of script to increase utilization',
                    epilog = 'Sorry if it does not work ;-;')

	parser.add_argument('-i', '--iterations', required=False, type=int, default=10, help='max number of iterations')
	parser.add_argument('-p', '--per_fu_type', required=False, action='store_false', default=True, help='determines if per FU counters are used')
	parser.add_argument('-s', '--score_mode', required=False, default="avg", nargs=1, help="Determines what scoring is used to find the 'best' result in design space. One of avg, rms, max, min" )
	parser.add_argument('-d', '--design_domain', required=False, default=[0.1,2.0], nargs=2, type=float, help="Determines how far away from initial settings the iterative gen is allowed to explore. Lower and upper bounds given as percent of original ie 0.5 2.0" )

	parser.add_argument('-v', '--verbosity', required=False, type=int, default=0, help='0 to 4')
	parser.add_argument('-l', '--logfile', required=False, default="", help='Name of logfile if desired, will redirect logging to file' )	

	#Ignore the first argument which is just the name of the script.
	args = parser.parse_args(sys.argv[1:])

	if( len(args.logfile) > 0 ):
		print("Logging redirected to: ", args.logfile)
		print("Verbosity set to: ", 50-10*args.verbosity)
		logging.basicConfig(format="%(asctime)s\t%(levelname)s\t%(message)s", level=50-10*args.verbosity, filename=args.logfile, encoding='utf-8')
	else:
		logging.basicConfig(format="%(asctime)s\t%(levelname)s\t%(message)s", level=50-10*args.verbosity)

	if( not args.score_mode in ["avg", "rms", "max", "min"]):
		print(f"Expected Argument score_mode to be one of avg/rms/max/min, saw {args.score_mode}")
		sys.exit(-1)
	
	logging.info(args) # Logging levels avalible: DEBUG INFO WARNING ERROR CRITICAL
	return args

#Start by checking that the run directory is valid ()
def init_sim():
	logging.info(f"Script Location : {SCRIPT_DIR}")
	logging.info(f"Script Run Location : {SCRIPT_RUN_DIR}")

	#Check for expected folders to see if we are in primate home
	if( not os.path.isdir( os.path.join(SCRIPT_RUN_DIR, "primate-uarch"))  or
	    not os.path.isdir( os.path.join(SCRIPT_RUN_DIR, "primate-arch-gen"))):
		logging.critical("Script should be run from primate home!")
		logging.critical("primate home is expected to contain following directories:")
		logging.critical("\t primate-arch-gen, primate-uarch")
		sys.exit(-1)

	if (DEBUG_SKIP_SCRIPTS):
		return

	#Execute first build in pktreassembly directory
	build_cmd = f"cd {os.path.join(SCRIPT_RUN_DIR, APP_PATH)} && {os.path.join(SCRIPT_DIR, 'scripts/dirty_build.sh')}"
	os.system(build_cmd)

def perform_iteration(cur_cyc: int):
	logging.info(f"Starting iteration {cur_cyc}")

	if (DEBUG_SKIP_SCRIPTS):
		return

	build_cmd = f"cd {os.path.join(SCRIPT_RUN_DIR, APP_PATH)} && {os.path.join(SCRIPT_DIR, 'scripts/dirty_rebuild.sh')}"
	os.system(build_cmd)

	build_cmd = f"cd {os.path.join(SCRIPT_RUN_DIR, EMULATOR_PATH)} && make -B verilator"
	os.system(build_cmd)
	pass

def modify_settings(cur_cycle: int):

	base_path = os.path.join(SCRIPT_RUN_DIR, APP_PATH) 
	base_path = os.path.join(base_path, "sw")

	#Update num FUS as needed
	next_settings["NUM_FUS"] = next_settings["NUM_ALUS"] + next_settings["NUM_BFUS"]

	#Perform needed modifications to [primate.cfg, primate_assembler.h] 
	with open( os.path.join(base_path, "primate.cfg"), "r") as fs:
		with open( os.path.join(base_path, "primate1.cfg"), "w" ) as fd:
			for o_line in fs:
				line = o_line.split("=")
				if( line[0] in next_settings):
					nl = f"{line[0]}={next_settings[line[0]]}\n"
					logging.debug(f"modifed line in primate.cfg { o_line.strip() } to {nl}")
					fd.write( nl )
				else:
					fd.write( o_line )

	os.system(f"mv {os.path.join(base_path, 'primate1.cfg')} {os.path.join(base_path, 'primate.cfg')}")

	with open( os.path.join(base_path, "primate_assembler.h"), "r") as fs:
		with open( os.path.join(base_path, "primate_assembler1.h"), "w" ) as fd:
			for o_line in fs:
				line = o_line.split(" ")
				if( line[0] == "#define" and line[1] in next_settings):
					nl = f"#define {line[1]} {next_settings[line[1]]}\n"
					logging.debug(f"modifed line in primate_assembler.h { o_line.strip() } to {nl}")
					fd.write( nl )
				else:
					fd.write( o_line )

	os.system(f"mv {os.path.join(base_path, 'primate_assembler1.h')} {os.path.join(base_path, 'primate_assembler.h')}")

	test_settings.append(next_settings)

def check_results(args: argparse.Namespace, cur_cyc: int):

	base_path = os.path.join(SCRIPT_RUN_DIR, OUT_VCD)

	list_of_files = glob.glob( os.path.join(base_path, "*") )
	latest_file = max(list_of_files, key=os.path.getmtime)
	if (not os.path.isdir(latest_file)):
		logging.critical(f"Expected folder, but found {latest_file}!")
		sys.exit(-1)
	if (check_results.Last_folder == latest_file):
		logging.critical(f"\n\nExpected new folder, but found newest folder is \n{latest_file},\nwhile last accessed folder is \n{check_results.Last_folder}\n")
	check_results.Last_folder = latest_file

	latest_file = os.path.join(latest_file, "Top.vcd")
	if ( not os.path.exists(latest_file) or not os.path.isfile(latest_file) ):
		logging.critical(f"Expected Top.vcd at {latest_file}, to be an openable file but was unable to open!")
		sys.exit(-1)

	logging.info(f"Found latest file of : {latest_file}")
	test_results.append( get_score_from_vcd( args, latest_file) )
	logging.info(f"\tCurrent Score of {test_results[-1]}")

	for i in range(10):
		sel_index = random.randint(0,2)
		sel_key = tuneable[sel_index]
		LB = int(args.design_domain[0] * default_settings[sel_key])
		UB = int(args.design_domain[1] * default_settings[sel_key])
		if( LB == UB ):
			continue
		
		high_index = 0
		high_score = test_results[0]

		for index in range( len(test_results), -1, -1 ):
			if(test_results[index] > high_score):
				high_index = index
				high_score = test_results[index]

		if( default_settings[sel_key] == test_settings[sel_key]):
			pass

		else:
			cmod = test_settings[sel_key] + default_settings[sel_key]
			newval = test_settings[sel_key] + cmod/abs(cmod)
			if( newval > UB or newval < LB ):
				continue

	else:
		logging.warning("Could not find new configuration within given paramaters, skipping modification")

#Variable for check_results() to ensure that folder is not reused
check_results.Last_folder = ""

def get_score_from_vcd( args: argparse.Namespace, filename: str):

	p="TOP.Top.result__type__engine__MT__16____class__primate."
	sig_list = []

	if( args.per_fu_type ):
		sig_list = [p+"bfu_max", p+"alu_max"]
		sig_list.extend([f"bfu_{i}_util" for i in range(next_settings["NUM_BFUS"])])
		sig_list.extend([f"alu_{i}_util" for i in range(next_settings["NUM_ALUS"])])
	else:
		sig_list = [p+"bfu_util",p+"bfu_max", p+"alu_util", p+"alu_max"]
	
	signals = get_signals_from_vcd(filename, sig_list)

	for signal_key in signals.keys():
		if( signal_key in [p+"bfu_max", p+"alu_max"]):
			continue
		elif ( signal_key[0:3] in ["bfu", "alu"]):			
			signals[signal_key] = signals[signal_key]/signals[signal_key[0:3]+"_max"]
		else:
			logging.warning(f"Unexpected signal key encountered when parsing vcd file, {signal_key}")

	del signals["bfu_max"]
	del signals["alu_max"]

	result = 0

	if(args.score_mode == "avg"):
		for signal_key in signals.keys():
			result = result + signals[signal_key]
		result = result/len(signals.keys())
	elif(args.score_mode == "rms"):
		for signal_key in signals.keys():
			result = result + (signals[signal_key] ** 2)
		result = ( result/len(signals.keys()) ) ** 0.5
	elif(args.score_mode in ["min","max"]):
		for i,signal_key in enumerate(signals.keys()):
			if(i==0):
				result = signals[signal_key]
			result = min(result, signals[signal_key]) if args.score_mode == "min" else max(result, signals[signal_key])
	else:
		logging.critical(f"Unexpected scoring mode given {args.score_mode}")
		sys.exit(-1)

	return result

def get_signals_from_vcd( filename: str, signalarray: list) -> dict:
	signal_dict = {}
	for signal_name in signalarray:
		signal_dict[signal_name] = get_signal_from_vcd(filename, signal_name)[1]
	return signal_dict
	

def get_signal_from_vcd( filename: str, signalname: str ) -> tuple:
	bits = None
	symbol = None
	value = None

	indv = False
	found_path = ""
	#Start by finding the symbol needed
	with open(filename) as fh: 
		for line in fh:
			line = line.strip()

			if(indv):
				if( len(line) > 3 and line == "$end" ):
					break
				elif( "#" == line[0] ):
					break	
				elif( symbol in line):
					value = line[0:-len(symbol)]

			if( len(line)>1 and line[0] == "$" ):
				
				if( len(line) > 8 and line[0:9] == "$dumpvars" ):
					indv = True
					if(symbol is None):
						break
					continue
				elif ( len(line) > 6 and line[0:6] == "$scope"):
					found_path =  ("" if len(found_path) == 0 else found_path + ".") + line.split(" ")[2] 

				elif ( len(line) > 8 and line[0:8] == "$upscope"):
					found_path = ".".join(found_path.split(".")[0:-1])

				elif ( len(line) > 4 and line[0:4] == "$var"):
					vl = line.split(" ")
					name = vl[4]
					if( found_path + "." + name == signalname ):
						bits = vl[2]
						symbol = vl[3]
					#else:
					#	print(f"{found_path + '.' + name} {signalname}")
			else:
				pass

	if(symbol is None):
		return None

	for line in reverse_readline(filename):
		if( len(line) > len(symbol) and line[-len(symbol):] == symbol):
			value = line[:-len(symbol)]
			break

	if ( value[0].isnumeric() ):
		pass
	elif( value[0] == 'b'):
		value = int(value[1:], 2)
	else:
		logging.warning(f"Unparsable literal found for symbol {symbol} of value {value}")

	return (symbol,value)

def report_results():
	logging.info("Successfully completed iterations")
	

#Taken from SO
def reverse_readline(filename, buf_size=8192):
    """A generator that returns the lines of a file in reverse order"""
    with open(filename) as fh:
        segment = None
        offset = 0
        fh.seek(0, os.SEEK_END)
        file_size = remaining_size = fh.tell()
        while remaining_size > 0:
            offset = min(file_size, offset + buf_size)
            fh.seek(file_size - offset)
            buffer = fh.read(min(remaining_size, buf_size))
            remaining_size -= buf_size
            lines = buffer.split('\n')
            # The first line of the buffer is probably not a complete line so
            # we'll save it and append it to the last line of the next buffer
            # we read
            if segment is not None:
                # If the previous chunk starts right from the beginning of line
                # do not concat the segment to the last line of new chunk.
                # Instead, yield the segment first 
                if buffer[-1] != '\n':
                    lines[-1] += segment
                else:
                    yield segment
            segment = lines[0]
            for index in range(len(lines) - 1, 0, -1):
                if lines[index]:
                    yield lines[index]
        # Don't yield None if the file was empty
        if segment is not None:
            yield segment
#End SO


if __name__ == "__main__":

	#Creates args object that holds inputed/default settings
	args = parse_args()

	init_sim()

	for i in range(args.iterations):
		modify_settings(i)
		perform_iteration(i)
		check_results(args, i)
		
	report_results()
	
