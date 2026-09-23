<?php

class OrderController extends Controller
{
    public function processOrders(array $orderIds): void
    {
        // ok: slopguard.php.laravel.query-in-loop
        $orders = Order::whereIn('id', $orderIds)->get()->keyBy('id');
        foreach ($orderIds as $id) {
            $orders[$id]->process();
        }
    }

    public function showUsers(array $userIds): array
    {
        // ok: slopguard.php.laravel.query-in-loop
        $users = User::whereIn('id', $userIds)->get();
        return $users->map(fn ($u) => $u->toArray())->all();
    }
}
