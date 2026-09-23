<?php

class ProductController extends Controller
{
    public function index()
    {
        // ok: slopguard.php.laravel.unbounded-all
        $products = Product::paginate(25);
        return view('products.index', ['products' => $products]);
    }

    public function export()
    {
        // ok: slopguard.php.laravel.unbounded-all
        return User::query()->chunkById(500, function ($users) {
            foreach ($users as $user) {
                // process user
            }
        });
    }
}
