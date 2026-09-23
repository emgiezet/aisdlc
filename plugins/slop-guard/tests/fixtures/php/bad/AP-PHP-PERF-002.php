<?php

class ProductController extends Controller
{
    public function index()
    {
        // ruleid: slopguard.php.laravel.unbounded-all
        $products = Product::all();
        return view('products.index', ['products' => $products]);
    }

    public function export()
    {
        // ruleid: slopguard.php.laravel.unbounded-all
        $users = User::all();
        return $users->toJson();
    }
}
