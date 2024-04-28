import json
import random
from datetime import timedelta, time, datetime
import time
import os
from azure.eventhub import EventHubProducerClient, EventData
import sys
import uuid

# Create following environment variables to publish events to Event Hub
# EVENTHUB_CONNECTION_STRING = ''
# EVENTHUB_NAME = 'manufacturing'
# HISTORICAL_DATA_DAYS = 7

EVENTHUB_CONNECTION_STRING = os.environ.get('EVENTHUB_CONNECTION_STRING')
EVENTHUB_NAME = os.environ.get('EVENTHUB_NAME')
HISTORICAL_DATA_DAYS = (0-int(os.environ.get('HISTORICAL_DATA_DAYS', 7)))  # This is to generate date prior to current date for dashboards.

# Create event producer as a global object to avoid connection creation overhead for each event.
if EVENTHUB_CONNECTION_STRING == "" or EVENTHUB_NAME == "":
    print('Event Hub connection string and/or Event Hub name not configured.')
    sys.exit()

# Initialize EventHub connection to send events
event_producer = EventHubProducerClient.from_connection_string(conn_str=EVENTHUB_CONNECTION_STRING, eventhub_name=EVENTHUB_NAME)

maintenance_last_generated = datetime.now()
production_last_generated = datetime.now()

# Define common schema templates to generate telemetry data
plant_details = [ 
    { "plant_id": "PT-01", "location": "Detroit, MI" },
    { "plant_id": "PT-02", "location": "Mexico City, MX" },
    { "plant_id": "PT-03", "location": "Shanghai, CN" },
    { "plant_id": "PT-04", "location": "Hamburg, DE" }
]

production_schedule = {"production_date": "2024-03-20", "scheduled_start": "20:00", "scheduled_end": "08:00", "planned_production_time_hours": 12, "actual_production_time_hours": 10}

employees = [
    {"employee_id": "E-001", "name": "John Doe", "role": "supervisor"},
    {"employee_id": "E-002", "name": "Jane Smith", "role": "engineer"},
    {"employee_id": "E-003", "name": "Mike Johnson", "role": "technician"}
]

cars_produced = [
    {"assembly_line": "AL-01", "car_id": "E-001", "model": "Sedan", "color": "red", "engine_type": "electric", "assembly_status": "none", "quality_check": "none" },
    {"assembly_line": "AL-02", "car_id": "H-002", "model": "SUV", "color": "blue", "engine_type": "hybrid", "assembly_status": "none", "quality_check": "none" },
    {"assembly_line": "AL-03", "car_id": "G-003", "model": "Coupe", "color": "black", "engine_type": "gasoline", "assembly_status": "none", "quality_check": "none" }
]

equipment_info = [
    {
        "equipment_id": "EQ-001",
        "type": "assembly_robot",
        "maintenance_schedule": "30d",
        "technical_specs": {}
    },
    {
        "equipment_id": "EQ-002",
        "type": "conveyor_belt",
        "maintenance_schedule": "10d",
        "technical_specs": {}
    },
    {
        "equipment_id": "EQ-003",
        "type": "paint_station",
        "maintenance_schedule": "90d",
        "technical_specs": {}
    },
    {
        "equipment_id": "EQ-004",
        "type": "welding-assembly_robot",
        "model": "RoboArm X2000",
        "maintenance_schedule": "15d",
        "technical_specs": {
            "arm_reach": "1.5 meters",
            "load_capacity": "10 kg",
            "precision": "0.02 mm",
            "rotation": "360 degrees"
        }
    },
    {
        "equipment_id": "WLD-001",
        "type": "welding_robot",
        "model": "WeldMaster 3000",
        "maintenance_schedule": "5d",
        "technical_specs": {
            "welding_speed": "1.5 meters per minute",
            "welding_technologies": ["MIG", "TIG"],
            "maximum_thickness": "10 mm",
            "precision": "+/- 0.5 mm"
        }
    }
]

# Equipment 
equipment_maintenance_history = [
    {
        "equipment_id": "WLD-001",
        "date": "2024-03-20",
        "start_time": "10:21",
        "end_time": "12:30",
        "type": "routine_check",
        "notes": "All systems operational, no issues found."
    },
    {
        "equipment_id": "WLD-001",
        "date": "2024-01-15",
        "start_time": "8:00",
        "end_time": "8:30",
        "type": "repair",
        "notes": "Replaced servo motor in joint 3."
    }
]

maintenance_types = [ 
    { "type": "routine_check", "message": "All systems operational, no issues found" },
    { "type": "emergency_check", "message": "Equipment is in critical condition, need immediate attention" }
]

production_shifts = [ 
    { "shift":"morning", "utc_start_hour":0, "utc_end_hour":7 },
    { "shift":"afternoon", "utc_start_hour":8, "utc_end_hour":15 },
    { "shift":"night", "utc_start_hour":16, "utc_end_hour":23 }    
]

# Get shift information
def get_shift(current_date_time):
    for shift in production_shifts:
        if current_date_time.hour >= shift['utc_start_hour'] and current_date_time.hour <= shift['utc_end_hour']:
            return shift['shift']

# produce this randomly with random delay between  1 to 3 hours
def simulate_equipment_maintenance(current_time):
    return {
        "equipment_id": "WLD-001",              # Pick random equipment
        "maintenance_date": str(current_time.date),
        "start_time": "10:21",                  # Produce random
        "end_time": "12:30",                    # Add random duration
        "type": "routine_check",
        "notes": "All systems operational, no issues found."
    }

# Produce equipment telemetry every 30 seconds or a minute
def simulate_equipment_telemetry(current_time):
    # Convert time string
    current_time = str(current_time)

    equipment_telemetry = [
        # Assembly Robot
        {
            "date_time": current_time,
            "equipment_id": "EQ-001",
            "type": "assembly_robot",
            "status": random.choice(["operational", "maintenance_required"]),   # Instead of random, use periodic maintenance
            "operational_time_hours": random.uniform(10, 12),
            "cycles_completed": random.randint(3400, 3500),
            "efficiency": random.uniform(93, 97),
            "maintenance_alert": random.choice(["none", "scheduled_check", "urgent_maintenance_required"]), # Instead of random, use periodic maintenance alerts
            "last_maintenance": "2024-02-20",
            "next_scheduled_maintenance": "2024-04-01"
        },
        # Conveyor Belt
        {
            "date_time": current_time,
            "equipment_id": "EQ-002",
            "type": "conveyor_belt",
            "status": random.choice(["operational", "maintenance_required"]),
            "operational_time_hours": random.uniform(10, 12),
            "distance_covered_meters": random.randint(10000, 12000),
            "efficiency": random.uniform(98, 99),
            "maintenance_alert": random.choice(["none", "scheduled_check"]),
            "last_maintenance": "2024-03-15",
            "next_scheduled_maintenance": "2024-03-30"
        },
        # Paint Station
        {
            "date_time": current_time,
            "equipment_id": "EQ-003",
            "type": "paint_station",
            "status": random.choice(["operational", "maintenance_required"]),
            "operational_time_hours": random.uniform(7, 9),
            "units_processed": random.randint(400, 500),
            "efficiency": random.uniform(90, 93),
            "maintenance_alert": random.choice(["none", "urgent_maintenance_required"]),
            "last_maintenance": "2024-02-25",
            "next_scheduled_maintenance": "Overdue"
        },
        # Welding-Assembly Robot
        {
            "date_time": current_time,
            "equipment_id": "EQ-004",
            "status": random.choice(["operational", "maintenance_required"]),
            "operational_time_hours": random.uniform(10, 12),
            "cycles_completed": random.randint(3400, 3500),
            "efficiency": random.uniform(94, 96),
            "maintenance_alert": random.choice(["none", "scheduled_check"]),
            "last_maintenance": "2024-03-20",
            "next_scheduled_maintenance": "2024-04-01",
            "operation_stats": {
                "average_cycle_time": "10 seconds",
                "failures_last_month": random.randint(1, 3),
                "success_rate": random.uniform(98.5, 99.9)
            }
        },
        # Welding Robot
        {
            "date_time": current_time,
            "equipment_id": "WLD-001",
            "status": random.choice(["operational", "maintenance_required"]),
            "operational_time_hours": random.uniform(9, 11),
            "welds_completed": random.randint(5100, 5300),
            "efficiency": random.uniform(97, 99),
            "maintenance_alert": random.choice(["none", "scheduled_check"]),
            "last_maintenance": "2024-03-22",
            "next_scheduled_maintenance": "2024-04-05",
            "operation_stats": {
                "average_weld_time": "30 seconds",
                "failures_last_month": random.randint(0, 3),
                "success_rate": random.uniform(98, 99.9)
            }
        }
    ]

    return equipment_telemetry

# Update assembly status with progress, start with in_progress and end with completed. Update status every 1 minutes
def simulate_production_telemetry():
    # Once the status completed change production id
    for car in cars_produced:
        car['assembly_status'] = random.choice(["completed", "in_progress"])
        if car['assembly_status'] == "completed":
            car['quality_check'] = random.choice(["pass", "fail"])

    return cars_produced

# Produce this data for every 8 hours
def simulate_production_by_shift():
    return {}

# Generate performance metrics
def generate_performance_metrics():
    return {
        "availability_oee": random.uniform(0.95, 0.99),
        "reject_rate": random.uniform(0.04, 0.06),
        "comments": "Minor downtime due to equipment maintenance. Overall production efficiency remains high."
    }

# Generate actual production data
def generate_actual_production_data(date_time):
    return {
        "start_time": "20:00",
        "end_time": "07:30",
        "actual_production_time_hours": 11.5,
        "production_downtime_hours": 0.5,
        "units_manufactured": random.randint(690, 710),
        "units_rejected": random.randint(30, 40),
        "details": [
            {"utc_hour": "20", "units_produced": random.randint(55, 60), "units_rejected": random.randint(2, 4)},
            # Additional hourly details can be added here
        ]
    }

# Produce assembly production data every minute for realtime data and every hour for historical data
def simulate_assembly_line_data(date_time):

    # Get current shift
    current_shift = get_shift(date_time)

    # Produce cars production progress data every time this method is called
    cars_produced = simulate_production_telemetry()

    # Produce cars production stats every one hour
    global maintenance_last_generated
    if int((date_time - maintenance_last_generated).total_seconds() / 60) > 5:
        actual_production = simulate_production_by_shift()
    else:
        actual_production = {}

    # Produce equipment telemetry data every time this method is called
    equipment_telemetry = simulate_equipment_telemetry(date_time)

    # Produce equipment maintenance data every 5 minutes
    global production_last_generated
    if int((date_time - production_last_generated).total_seconds() / (5 *60)) > 5:
        equipment_maintenance = simulate_equipment_maintenance(date_time)
        maintenance_last_generated = date_time
    else:
        equipment_maintenance = {}

    # Make this by shift  production information
    actual_production = generate_actual_production_data(date_time)
    
    # Include in the hourly production performance metrics
    performance_metrics = generate_performance_metrics()

    # Split this into hourly and by shift
    current_time = date_time.isoformat() + "Z"
    simulation_data = {
        "date_time": current_time,
        "plant_details": plant_details[random.randint(0, len(plant_details)-1)],
        "shift": current_shift,
        "employees_on_shift": employees,
        "cars_produced": cars_produced,
        "equipment_maintenance": equipment_maintenance,
        "production_schedule": production_schedule,
        "actual_production": actual_production,
        "equipment_telemetry": equipment_telemetry,
        "performance_metrics": performance_metrics
    }

    return simulation_data

def send_product_to_event_hub(simulation_data):

    # format data to pubish into staging table
    payload_data = {
            "id": str(uuid.uuid4()),
            "source": "data_emulator",
            "type": "data_emulator",
            "data_base64": simulation_data,  # Data in JSON format
            "time": str(datetime.now().isoformat()) + "Z",
            "specversion": 1,
            "subject": "topic/dataemulator"
        }
    event_data = EventData(json.dumps(payload_data))
    event_producer.send_batch([event_data])

if __name__ == "__main__":

    # Generate batch and continue with live data
    user_option = input("Would you like generate past data (1) or current data (2) choose your option: ")
    if user_option == "":
        user_option = 1
    else:
        user_option = int(user_option)

    if user_option == 1:
        number_of_days = input("Enter number of days to generate past data (default is 7 days): ")
        if number_of_days == "":
            number_of_days = -7
        else:
            number_of_days = (0 - int(number_of_days))
    
        production_datetime = datetime.now() + timedelta(days=number_of_days)

    try:
        if user_option == 1:
            while production_datetime <= datetime.now():
                print('Generating for: ', production_datetime)
                simulated_data = simulate_assembly_line_data(production_datetime)
                send_product_to_event_hub(simulated_data)

                # Increment time
                production_datetime += timedelta(minutes=1)
        else:
            # Generate live data
            print('Now generating live date...')
            while True:
                current_time = datetime.now()
                # Produce equipment telemetry data every 30 seconds
                print('Generating for: ', current_time)
                simulated_data = simulate_assembly_line_data(current_time)
                send_product_to_event_hub(simulated_data)

                time.sleep(30)  # send data every 30 seconds
    finally:
        event_producer.close()
