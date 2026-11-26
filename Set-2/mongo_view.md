db.createView(
    "vw_unresolved_complaints",
    "customer_communications",
    [
        {
            $match: {
                communicationType: "Complaint",
                status: "Unresolved"
            }
        }
    ]
);

// Display unresolved complaints
db.vw_unresolved_complaints.find();
