db.createView(
    "vw_order_status_counts",
    "orders",
    [
        {
            $group: {
                _id: "$status",
                orderCount: { $sum: 1 }
            }
        },
        {
            $project: {
                _id: 0,
                status: "$_id",
                orderCount: 1
            }
        },
        {
            $sort: { status: 1 }
        }
    ]
);

// Display the view
db.vw_order_status_counts.find();
