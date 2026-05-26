<?php
// ============================================================
// app/Models/User.php
// ============================================================
namespace App\Models;

use Laravel\Sanctum\HasApiTokens;
use Illuminate\Foundation\Auth\User as Authenticatable;

class User extends Authenticatable
{
    use HasApiTokens;

    protected $table      = 'users';
    protected $primaryKey = 'user_id';
    public    $timestamps = false;

    protected $fillable = [
        'username','password','full_name','role','status','currency'
    ];

    protected $hidden = ['password'];

    protected $casts = [
        'role'     => 'string',
        'status'   => 'string',
        'currency' => 'string',
    ];
}
