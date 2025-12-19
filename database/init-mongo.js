// MongoDB Initialization Script for FlightSearchAPI
// Run this script after the API is running to populate sample data

// Switch to flightdatabase
db = db.getSiblingDB('flightdatabase');

print('=== FlightSearchAPI Database Initialization ===\n');

// 1. Check existing data
print('Current state:');
print('Users: ' + db.users.countDocuments());
print('Airports: ' + db.airports.countDocuments());
print('Flights: ' + db.flights.countDocuments());
print('Tokens: ' + db.tokens.countDocuments());
print('');

// 2. Create indexes (if not exist)
print('Creating indexes...');

// Users collection indexes
db.users.createIndex({ "email": 1 }, { unique: true, name: "email_unique_idx" });

// Airports collection indexes
db.airports.createIndex({ "name": "text" }, { name: "name_text_idx" });
db.airports.createIndex({ "cityName": 1 }, { name: "cityName_idx" });

// Flights collection indexes
db.flights.createIndex({ "fromAirportId": 1 }, { name: "fromAirport_idx" });
db.flights.createIndex({ "toAirportId": 1 }, { name: "toAirport_idx" });
db.flights.createIndex({ "departureTime": 1 }, { name: "departure_idx" });
db.flights.createIndex({ "arrivalTime": 1 }, { name: "arrival_idx" });
db.flights.createIndex(
    { "fromAirportId": 1, "toAirportId": 1, "departureTime": 1 },
    { name: "flight_search_idx" }
);

// Tokens collection indexes
db.tokens.createIndex({ "refreshToken": 1 }, { unique: true, name: "token_unique_idx" });
db.tokens.createIndex({ "userId": 1 }, { name: "userId_idx" });
db.tokens.createIndex({ "expiresAt": 1 }, { expireAfterSeconds: 0, name: "token_ttl_idx" });

print('Indexes created successfully!\n');

// 3. Insert sample airports (only if empty)
if (db.airports.countDocuments() === 0) {
    print('Inserting sample airports...');
    
    const airports = [
        {
            _id: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            name: "Istanbul Airport",
            cityName: "Istanbul",
            createdAt: new Date(),
            updatedAt: new Date()
        },
        {
            _id: "b2c3d4e5-f6a7-5b6c-9d0e-1f2a3b4c5d6e",
            name: "Ataturk Airport",
            cityName: "Istanbul",
            createdAt: new Date(),
            updatedAt: new Date()
        },
        {
            _id: "c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f",
            name: "Ankara Esenboga Airport",
            cityName: "Ankara",
            createdAt: new Date(),
            updatedAt: new Date()
        },
        {
            _id: "d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a",
            name: "Izmir Adnan Menderes Airport",
            cityName: "Izmir",
            createdAt: new Date(),
            updatedAt: new Date()
        },
        {
            _id: "e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b",
            name: "Antalya Airport",
            cityName: "Antalya",
            createdAt: new Date(),
            updatedAt: new Date()
        }
    ];
    
    db.airports.insertMany(airports);
    print('Inserted ' + airports.length + ' airports\n');
} else {
    print('Airports already exist, skipping...\n');
}

// 4. Insert sample flights (only if empty)
if (db.flights.countDocuments() === 0) {
    print('Inserting sample flights...');
    
    const now = new Date();
    const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const nextWeek = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
    
    const flights = [
        // Istanbul -> Ankara
        {
            _id: "f1a2b3c4-d5e6-4f5a-6b7c-8d9e0f1a2b3c",
            fromAirportId: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            toAirportId: "c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f",
            departureTime: new Date(tomorrow.setHours(10, 0, 0, 0)),
            arrivalTime: new Date(tomorrow.setHours(11, 15, 0, 0)),
            price: NumberDecimal("250.50"),
            createdAt: now,
            updatedAt: now
        },
        {
            _id: "f2b3c4d5-e6f7-5a6b-7c8d-9e0f1a2b3c4d",
            fromAirportId: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            toAirportId: "c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f",
            departureTime: new Date(tomorrow.setHours(15, 30, 0, 0)),
            arrivalTime: new Date(tomorrow.setHours(16, 45, 0, 0)),
            price: NumberDecimal("280.00"),
            createdAt: now,
            updatedAt: now
        },
        // Istanbul -> Izmir
        {
            _id: "f3c4d5e6-f7a8-6b7c-8d9e-0f1a2b3c4d5e",
            fromAirportId: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            toAirportId: "d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a",
            departureTime: new Date(tomorrow.setHours(8, 0, 0, 0)),
            arrivalTime: new Date(tomorrow.setHours(9, 20, 0, 0)),
            price: NumberDecimal("320.75"),
            createdAt: now,
            updatedAt: now
        },
        // Istanbul -> Antalya
        {
            _id: "f4d5e6f7-a8b9-7c8d-9e0f-1a2b3c4d5e6f",
            fromAirportId: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            toAirportId: "e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b",
            departureTime: new Date(nextWeek.setHours(12, 0, 0, 0)),
            arrivalTime: new Date(nextWeek.setHours(13, 30, 0, 0)),
            price: NumberDecimal("450.00"),
            createdAt: now,
            updatedAt: now
        },
        // Ankara -> Istanbul
        {
            _id: "f5e6f7a8-b9c0-8d9e-0f1a-2b3c4d5e6f7a",
            fromAirportId: "c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f",
            toAirportId: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            departureTime: new Date(tomorrow.setHours(18, 0, 0, 0)),
            arrivalTime: new Date(tomorrow.setHours(19, 15, 0, 0)),
            price: NumberDecimal("260.00"),
            createdAt: now,
            updatedAt: now
        },
        // Izmir -> Istanbul
        {
            _id: "f6f7a8b9-c0d1-9e0f-1a2b-3c4d5e6f7a8b",
            fromAirportId: "d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a",
            toAirportId: "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d",
            departureTime: new Date(tomorrow.setHours(20, 30, 0, 0)),
            arrivalTime: new Date(tomorrow.setHours(21, 50, 0, 0)),
            price: NumberDecimal("310.50"),
            createdAt: now,
            updatedAt: now
        }
    ];
    
    db.flights.insertMany(flights);
    print('Inserted ' + flights.length + ' flights\n');
} else {
    print('Flights already exist, skipping...\n');
}

// 5. Display final counts
print('=== Database initialized successfully! ===\n');
print('Final counts:');
print('Users: ' + db.users.countDocuments());
print('Airports: ' + db.airports.countDocuments());
print('Flights: ' + db.flights.countDocuments());
print('Tokens: ' + db.tokens.countDocuments());
print('');

// 6. Display sample data
print('=== Sample Airports ===');
db.airports.find().limit(3).forEach(airport => {
    print('- ' + airport.name + ' (' + airport.cityName + ')');
});

print('\n=== Sample Flights ===');
db.flights.find().limit(3).forEach(flight => {
    print('- From: ' + flight.fromAirportId + ' To: ' + flight.toAirportId);
    print('  Departure: ' + flight.departureTime);
    print('  Price: $' + flight.price);
});

print('\n=== IMPORTANT NOTES ===');
print('1. Users must be created via API /api/v1/authentication/user/register');
print('2. Sample data includes 5 airports and 6 flights');
print('3. All indexes have been created for optimal performance');
print('4. To test the API, first register a user (see database/README.md)');
print('');
