package com.illposed.osc;

import java.util.Date;

public class MatlabOSCListener implements OSCListener {
	
	private Date date;
	private OSCMessage message;

	@Override
	public void acceptMessage(Date arg0, OSCMessage arg1) {
		this.date = arg0;
		this.message = arg1;
	}
	
	public Date getTimeStamp(){
		return date;
	}
	
	public OSCMessage getMessage(){
		return message;
	}
	
	public Object[] getMessageArguments(){
		Object[] arguments = null;
		if(message != null){
			arguments = message.getArguments();
			message = null;
		}
		return arguments;
	}
	
	public double[] getMessageArgumentsAsDouble(){
		Object[] arguments = getMessageArguments();
		double[] doubleArguments = null; 
		if(arguments != null && arguments.length > 0){
			doubleArguments = new double[arguments.length];
			for(int i = 0 ; i < arguments.length ; i++){
				//since it is not known if the object is either a float, integer or double
				// do a to string and cast it.
				// this will fail for non nummeric data types
				doubleArguments[i] = Double.valueOf(arguments[i].toString());
			}
		}
		return doubleArguments;
	}
	
	public String[] getMessageArgumentsAsString(){
		Object[] arguments = getMessageArguments();
		String[] stringArguments = null; 
		if(arguments != null && arguments.length > 0){
			stringArguments = new String[arguments.length];
			for(int i = 0 ; i < arguments.length ; i++){
				stringArguments[i] = arguments[i].toString();
			}
		}
		return stringArguments;
	}
	
	public static void main(String... args){}
}
