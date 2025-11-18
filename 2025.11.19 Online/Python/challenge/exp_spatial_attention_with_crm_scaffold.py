'''
Scaffold/Template version of the SRM-CRM experiment for students.
This version uses BeRTA (Binaural Rendering Toolbox Application) via OSC to generate spatial audio.

Students should:
1. Install BeRTA on their system
2. Configure the BeRTA path and OSC ports below
3. Implement sound rendering via the render_sound_via_osc() method
4. Handle timing for sound playback completion

Required Python packages:
    pip install python-osc spatialaudiometrics customtkinter CTkMessagebox
'''
import os
# import yaml
from importlib import resources as impresources
import time
import datetime
import numpy as np
import customtkinter as ctk
from CTkMessagebox import CTkMessagebox
import pandas as pd
from pythonosc import udp_client
from pythonosc.dispatcher import Dispatcher
from pythonosc.osc_server import BlockingOSCUDPServer
import subprocess
from spatialaudiometrics import angular_metrics as am
from spatialaudiometrics import signal_processing as sp
import stimuli

class Parameters:
    '''
    Stores parameters that shouldn't be changed
    '''
    m_talkers               = [0,1,2,3]
    f_talkers               = [4,5,6,7]
    red                     = '#e71d36'
    green                   = '#7fb285'
    blue                    = '#0072bb'
    white                   = '#ffffff'
    crm_numbers             = [1,2,3,4,5,6,7]
    crm_colours             = ['white','green','red','blue']
    crm_button_colours      = [white,green,red,blue]
    crm_button_text_colours = ['black','black','white','white']
    crm_button_dict         = []
    listener                = list()
    full_trial_df           = []
    log                     = pd.DataFrame()
    log_fname               = pd.DataFrame()
    trial_idx               = -1
    sound_played_flag       = False
    sound_duration_estimate = 3.0
    
    # ==================== BeRTA Configuration ====================
    # These will be set during initialisation
    berta_process           = None
    berta_client            = None
    osc_server              = None

class SpatialAttention(ctk.CTk):
    '''
    Experiment for spatial attention
    '''
    def prepare_sound(self,config):
        '''
        Prepares the sound by collecting trial information and sending to external renderer via OSC
        '''
        if Parameters.trial_idx < len(Parameters.full_trial_df)-1:
            Parameters.trial_idx += 1
            self.progress_bar.set(Parameters.trial_idx/len(Parameters.full_trial_df))
            curr_trial      = Parameters.full_trial_df.iloc[Parameters.trial_idx]
            el              = 0
            az_locations    = [curr_trial.target_location]
            filenames       = [curr_trial.target_fname]
            for m in range(curr_trial.curr_masker_number):
                az_locations.append(curr_trial.masker_location)
                filenames.append(curr_trial['masker' + str(m+1) + '_fname'])

            trial_info = {
                'target_location': curr_trial.target_location,
                'target_talker': curr_trial.target_talker,
                'target_callsign': curr_trial.target_callsign,
                'target_colour': curr_trial.target_colour,
                'target_number': curr_trial.target_number,
                'target_fname': curr_trial.target_fname,
                'num_maskers': curr_trial.curr_masker_number,
                'masker_locations': az_locations[1:],
                'masker_filenames': filenames[1:],
                'hrtf': curr_trial.HRTFname
            }
            
            print(f"\n[PREPARE_SOUND] Trial {Parameters.trial_idx + 1}:")
            print(f"  Target: {trial_info['target_colour']} {trial_info['target_number']} (Talker {trial_info['target_talker']})")
            print(f"  Target location: {trial_info['target_location']}°")
            print(f"  Number of maskers: {trial_info['num_maskers']}")
            if trial_info['masker_locations']:
                print(f"  Masker locations: {trial_info['masker_locations']}")
            print(f"  HRTF: {trial_info['hrtf']}")
            
            # Send OSC messages to external renderer
            self.load_sound_via_osc(trial_info)

        else:
            if config['practice']:
                config['practice'] = False
                msg = CTkMessagebox(title="", message="Practice over! Click ok to continue",
                    icon="info", option_1="Ok")
                self.label_practice.configure(text = '')
                Parameters.trial_idx        = -1
                Parameters.full_trial_df    = self.generate_trials(config)

                # Generate practice trials
                self.prepare_sound(config)
            else:
                msg = CTkMessagebox(title="", message="Experiment over! Please let the experimenter know",
                    icon="check")
    
    def load_sound_via_osc(self, trial_info):
        '''
        Sends OSC messages to BeRTA to render spatial audio for the trial
        
        This method:
        1. Loads audio files via BeRTA
        2. Positions sources in 3D space using spherical coordinates
        
        :param trial_info: Dictionary containing trial information
        :param config: Configuration dictionary with BeRTA settings
        '''
        # ==================== Load sounds into BRT ====================
        # Write code to load the sources into berta based on trial_info

        # ==============================================================
        
    def get_talker_filename(self,talker,callsign,colour,number):
        '''
        Gets the filename for each talker
        
        :param talker: talker number
        :param callsign: the callsign said
        :param colour: the colour said
        :param number: the number said
        '''
        number_names    = ['one','two','three','four','five','six','seven','eight','nine','ten']
        curr_number     = number_names[number-1]
        keyword         = callsign + '_' + colour + '_' + curr_number + ".wav"
        for fname in os.listdir(impresources.files(stimuli).joinpath('crm/Talker' + str(talker) + '/')):
            if keyword in fname:
                filename = impresources.files(stimuli).joinpath('crm/Talker' + str(talker) + '/' + fname)
        return filename
    
    def generate_trials(self,config):
        '''
        Generates a trial for each m and f talker, target locations, masker locations, hrtfs and randomises
        
        :returns trial_df: Creates a pandas dataframe where each row is a trial with all the information for each trial 
        '''
        trial_df = pd.DataFrame()

        for r in range(config['repeats']):
            block_df  = pd.DataFrame()
            for g in range(2): # for m and f talkers
                for t,t_loc in enumerate(config['target_locations']):
                    for l, loc in enumerate(config['masker_locations']):
                        for h, hrtf in enumerate(config['hrtfs']):
                            # Randomise talker and maskers between male and female talkers
                            if g == 0:
                                talkers     = Parameters.m_talkers
                            else:
                                talkers     = Parameters.f_talkers
                            talkers         = np.random.permutation(talkers)
                            # Randomise answers
                            colours         = np.random.permutation(Parameters.crm_colours)
                            numbers         = np.random.permutation(Parameters.crm_numbers)
                            callsigns       = np.random.permutation(config['crm_callsigns'])
                            
                            hrtfname        = h
                            target_fname    = self.get_talker_filename(talkers[0],'baron',colours[0],numbers[0])
                            curr_masker_number = config['number_of_maskers']
                            temp            = pd.DataFrame([[0,config['subject'],config['datestr'],h,hrtfname,t_loc,loc,
                                            talkers[0],'baron',colours[0],numbers[0],target_fname,curr_masker_number]],
                                            columns = ['trial_number','subject','datetime_start','HRTFidx','HRTFname','target_location','masker_location',
                                                        'target_talker','target_callsign','target_colour','target_number','target_fname','curr_masker_number'])
                            
                            # Get details for the maskers
                            for m in range(config['number_of_maskers']):
                                masker_fname   = self.get_talker_filename(talkers[m+1],callsigns[m],colours[m+1],numbers[m+1])
                                temp['masker' + str(m+1) + '_talker'] = talkers[m+1]
                                temp['masker' + str(m+1) + '_callsign'] = callsigns[m]
                                temp['masker' + str(m+1) + '_colour'] = colours[m+1]
                                temp['masker' + str(m+1) + '_number'] = numbers[m+1]
                                temp['masker' + str(m+1) + '_fname'] = masker_fname

                            block_df = pd.concat([block_df,temp])
            block_df = block_df.sample(frac = 1)
            trial_df = pd.concat([trial_df,block_df])
        trial_df = trial_df.reset_index(drop = True)
        trial_df['trial_number'] = np.arange(0,len(trial_df),1)
        print('Generated ' + str(len(trial_df)) + ' trials')
        return trial_df

    def quit(self):
        '''
        Quits the app. For some reason I can't get the wierd terminal warnings to stop when trying to quit the window
        '''
        self.withdraw()
        self.destroy()
    
    def give_feedback(self,config,colour,number):
        '''
        Gives feedback by changing the button borders
        '''
        curr_trial  = Parameters.full_trial_df.iloc[Parameters.trial_idx-1]
        b_name      = curr_trial.target_colour + ' ' + str(curr_trial.target_number)
        Parameters.crm_button_dict[b_name].configure(border_color = 'green',border_width = 8)

        if (curr_trial.target_colour != colour) | (curr_trial.target_number!= number):
            b_name = colour + ' ' + str(number)
            Parameters.crm_button_dict[b_name].configure(border_color = 'red',border_width = 8)
    
    def remove_feedback(self):
        '''
        Removes all feedback borders
        '''
        for key in Parameters.crm_button_dict:
            Parameters.crm_button_dict[key].configure(border_width = 0)

    def store_answer(self,config,colour,number):
        '''
        Get the answer and save it in self
        '''
        if Parameters.sound_played_flag == True:
            print(f'\n[STORE_ANSWER] User pressed: {colour} {number}')
            self.shade_button(colour,number)
            if config['practice'] == True:
                self.give_feedback(config,colour,number)
                print(f'[FEEDBACK] Showing feedback for response')
            # Store answer
            if Parameters.trial_idx >= 0:
                # Store the answer from the previous trial
                curr_trial = Parameters.full_trial_df.iloc[Parameters.trial_idx-1:Parameters.trial_idx].reset_index(drop=True)
                curr_trial['response_colour'] = colour
                curr_trial['response_number'] = number
                curr_trial['curr_datetime']   = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
                # Concat if trial_idx is greater than the length of log, or replace if not (since someone has changed their answer)
                if len(Parameters.log) == Parameters.trial_idx:
                    # Replace
                    self.unshade_button(Parameters.log.iloc[Parameters.trial_idx-1].response_colour,Parameters.log.iloc[Parameters.trial_idx-1].response_number)
                    Parameters.log.iloc[Parameters.trial_idx-1] = curr_trial.iloc[0]
                else:
                    Parameters.log = pd.concat([Parameters.log,curr_trial])
                    
                Parameters.log = Parameters.log.reset_index(drop=True)
                try:
                    Parameters.log.to_csv(Parameters.log_fname)
                except OSError: # Create a test data directory if not there
                    os.mkdir(config['data_dir'] + config['test'])
                    
            self.button_play.configure(state = 'normal')

    def change_crm_button_grid_state(self,state):
        '''
        Changes the state of the CRM buttons between disabled, active and normal
        '''
        for key in Parameters.crm_button_dict:
            Parameters.crm_button_dict[key] = state

    def create_buttons(self,config):
        """ 
        Creates a button grid for all the CRM resposnes, and stores the button 
        to a dictionary and then  when they are clicked itll send the choice to
        get_answer
        """
        crm_button_dict = dict()
        for row, colour in enumerate(Parameters.crm_colours):
            for col, number in enumerate(Parameters.crm_numbers):
                b_name = colour + ' ' + str(number)
                # Link function to each button and bind the value at the time the anonymous function is created
                crm_button_dict[b_name] = ctk.CTkButton(self, text = b_name, fg_color= Parameters.crm_button_colours[row], 
                                                        text_color = Parameters.crm_button_text_colours[row],width = 140, height = 70, font = ("Arial",20,'bold'),
                                                        command = lambda colour = colour, number = number: self.store_answer(config,colour,number),text_color_disabled = 'grey')
                crm_button_dict[b_name].grid(row = row + 3, column=col + 1)
        return crm_button_dict

    def shade_button(self,colour,number):
        '''
        Changes the button to a different colour when it is selected
        '''
        b_name = colour + ' ' + str(number)
        Parameters.crm_button_dict[b_name].configure(fg_color = 'purple')

    def unshade_button(self,colour,number):
        '''
        Changes the button back to normal
        '''
        b_name = colour + ' ' + str(number)
        try:
            Parameters.crm_button_dict[b_name].configure(fg_color= Parameters.crm_button_colours[Parameters.crm_colours.index(colour)])
        except TypeError: # Sometimes happens if the pandas entry is in the wrong format
            b_name = colour.values[0] + ' ' + str(number)
            Parameters.crm_button_dict[b_name].configure(fg_color= Parameters.crm_button_colours[Parameters.crm_colours.index(colour.values[0])])

    def generate_practice_trials(self,config):
        '''
        Generates 10 practice trials
        '''
        trial_df = pd.DataFrame()

        talker_gender       = [0,1,0,1,0,1,0,1,0,1]
        hrtf                = config['hrtfs'][0]
        t_loc               = 0
        number_of_maskers   = [0,0,0,0,1,1,1,1,2,2]
        masker_locations    = [0,0,0,0,180,180,90,0,90,0]
        
        for t,g in enumerate(talker_gender):
            loc                 = masker_locations[t]
            curr_masker_number  = number_of_maskers[t]

            if g == 0:
                talkers     = Parameters.m_talkers
            else:
                talkers     = Parameters.f_talkers
            talkers         = np.random.permutation(talkers)
            # Randomise answers
            colours         = np.random.permutation(Parameters.crm_colours)
            numbers         = np.random.permutation(Parameters.crm_numbers)
            callsigns       = np.random.permutation(config['crm_callsigns'])
            
            hrtfname        = config['hrtfs'][0]
            target_fname    = self.get_talker_filename(talkers[0],'baron',colours[0],numbers[0])
            temp            = pd.DataFrame([[0,config['subject'],config['datestr'],0,hrtfname,t_loc,loc,
                            talkers[0],'baron',colours[0],numbers[0],target_fname,curr_masker_number]],
                            columns = ['trial_number','subject','datetime_start','HRTFidx','HRTFname','target_location','masker_location',
                                        'target_talker','target_callsign','target_colour','target_number','target_fname','curr_masker_number'])
            # Get details for the maskers
            for m in range(curr_masker_number):
                masker_fname   = self.get_talker_filename(talkers[m+1],callsigns[m],colours[m+1],numbers[m+1])
                temp['masker' + str(m+1) + '_talker'] = talkers[m+1]
                temp['masker' + str(m+1) + '_callsign'] = callsigns[m]
                temp['masker' + str(m+1) + '_colour'] = colours[m+1]
                temp['masker' + str(m+1) + '_number'] = numbers[m+1]
                temp['masker' + str(m+1) + '_fname'] = masker_fname

            trial_df = pd.concat([trial_df,temp])
        trial_df                    = trial_df.reset_index(drop = True)
        trial_df['trial_number']    = np.arange(0,len(trial_df),1)

        return trial_df
        
    def __init__(self,config):
        '''
        Initialises the experiment GUI and BeRTA connection
        '''
        ctk.CTk.__init__(self)
        
        # ==================== Initialize BeRTA Connection ====================
        # Open and connect to BeRTA here


        # ==================== Load HRTFs here ===========================
        # Load HRTF for each trial configuration 

            
        # ====================================================================

        # Initialise log file
        config['datestr']           = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
        Parameters.log_fname        = config['data_dir'] + config['test'] + '/' + config['datestr'] + '_' + config['subject'] + '_' + config['test'] +'.csv'

        # Initialise GUI
        ctk.set_appearance_mode("dark")
        self.title("Spatial Attention experiment")
        self.geometry("1400x800")
        self.grid_columnconfigure([0,9], weight=1)
        self.grid_rowconfigure([0,7,10], weight=1)

        label = ctk.CTkLabel(self, text="Please select the colour and number said by the talker that said 'Ready Baron go to [colour] [number] now", 
                             fg_color="transparent", text_color= 'white',font = ("Arial",20,'bold'))
        label.grid(row = 2, column = 1, padx=20, pady=20,columnspan = 7)
        self.progress_bar = ctk.CTkProgressBar(self, orientation='horizontal', mode='determinate',progress_color = 'green')
        self.progress_bar.grid(row=10, column=1, pady=10, padx=20, columnspan = 7)
        self.progress_bar.set(0)

        button_exit = ctk.CTkButton(self, text="Exit!",  fg_color = 'orange', text_color = 'black', font = ("Arial",20,'italic'), command = self.quit)
        button_exit.grid(row=1, column=10, padx=20, pady=20)

        self.button_play = ctk.CTkButton(self, text="Play!",  fg_color = 'purple', text_color = 'white', font = ("Arial",20,'italic'), 
                                    command = lambda: self.play_sound(config))
        self.button_play.grid(row = 7, column=4)

        # Set up answer buttons 
        Parameters.crm_button_dict = self.create_buttons(config)

        # Creates a practice set of trials, useful for debugging before the full experiment 
        if config['practice'] == True:
            self.label_practice = ctk.CTkLabel(self, text="Practice round!", 
                        fg_color="transparent", text_color= 'white',font = ("Arial",22,'bold'))
            self.label_practice.grid(row = 1, column = 1, padx=20, pady=20,columnspan = 7)

            Parameters.full_trial_df = self.generate_practice_trials(config)
            self.prepare_sound(config)
    
        else:
            Parameters.full_trial_df    = self.generate_trials(config)
            self.prepare_sound(config)

    def play_sound(self, config):
        '''
        Plays the sound via BeRTA and waits for completion before preparing next trial
        '''
        self.remove_feedback()
        self.button_play.configure(state = 'disabled')
        if Parameters.trial_idx > 0:
            self.unshade_button(Parameters.log.iloc[Parameters.trial_idx-1].response_colour,Parameters.log.iloc[Parameters.trial_idx-1].response_number)
        
        time.sleep(0.001) # To update the GUI
        
        trial_info = Parameters.full_trial_df.iloc[Parameters.trial_idx]


        # ==================== Play and move sound here ===========================

        

        # ========================================================================

        # Then prepare the next sound
        self.prepare_sound(config)


def main():
    '''
    Main function to run the experiment
    '''
    # Load config
    import yaml
    with open('config.yml', 'r') as file:
        config = yaml.load(file, Loader = yaml.SafeLoader)

    # Run experiment
    app = SpatialAttention(config)
    # with app:
    app.mainloop()

if __name__ == "__main__":
    main()