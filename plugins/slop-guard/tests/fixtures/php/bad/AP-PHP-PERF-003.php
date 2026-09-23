<?php

class OrderController extends Controller
{
    public function processOrders(array $orderIds): void
    {
        foreach ($orderIds as $id) {
            // ruleid: slopguard.php.laravel.query-in-loop
            $order = Order::find($id);
            $order->process();
        }
    }

    public function showUsers(array $userIds): array
    {
        $results = [];
        foreach ($userIds as $userId) {
            // ruleid: slopguard.php.laravel.query-in-loop
            $user = User::where('id', $userId)->first();
            $results[] = $user->toArray();
        }
        return $results;
    }
}
