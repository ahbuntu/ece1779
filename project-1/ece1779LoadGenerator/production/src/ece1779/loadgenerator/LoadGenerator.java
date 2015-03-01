package ece1779.loadgenerator;

import java.util.Date;
import java.util.Vector;

public class LoadGenerator {
	
	private final int INTERVAL = 10;
	private int numActive=0;
	private long latency=0;
	private Vector throughput = new Vector();
	private String protocol="http://";
	private String server="";
	private String port=":8080";
	private String servlet="/ece1779/servlet/FileUpload";
	private GUI gui;
	
	static public void main(String [] args) {
		if (args == null || args.length < 1) {
			System.out.println("Usage!  java ece1779.loadgenerator.LoadGenerator server_ip_address");
			return;
		}
		LoadGenerator generator = new LoadGenerator(args);
	}

	public LoadGenerator(String [] args) {
		server = args[0];
		gui = new GUI(this);
		gui.setVisible(true);
		gui.refresh();
	}
	
	public void addWorker() {
		Worker worker = new Worker(this,getNextID());
		worker.start();
		gui.refresh();
	}
	
	public void stopWorker() {
		if (numActive > 0)
			numActive--;
		gui.refresh();
	}
	
	
	private int getNextID() {
		return ++numActive;
	}
	
	public int getNumActive() {
		return numActive;
	}

	public void setNumActive(int numActive) {
		this.numActive = numActive;
	}

	synchronized public float getThroughput() {
		float th = 0;
		
		if (throughput.size() < 2)
			return th;
		
		long last = ((Date)throughput.elementAt(0)).getTime();
		
		long current = last;
		float count=0;
		
		for (int x=1; x < throughput.size() && (last-current < INTERVAL*1000); x++) {
			current = ((Date)throughput.elementAt(x)).getTime();
			count++;
		}
		
		return count/INTERVAL;
	}
	
	
	public long getLatency() {
		return latency;
	}

	public void setLatency(long latency) {
		this.latency = latency;
	}

	synchronized public void log(String msg) {
		gui.log(msg);

	}

	public String getServerURL() {
		return protocol + server + port + servlet;
	}

	synchronized public void reportLatency(long lat) {
		throughput.insertElementAt(new Date(),0);
		
		// TODO Auto-generated method stub
		if (latency == 0)
			latency = lat;
		latency = (long) (latency * 0.9 + lat * .1);
		gui.refresh();
		
	}

	
	
}
