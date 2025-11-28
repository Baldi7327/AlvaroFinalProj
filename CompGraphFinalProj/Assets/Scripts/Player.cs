using System.Collections;
using UnityEngine;

public class Player : MonoBehaviour
{
    [Header("Camera")]
    [SerializeField] private float mouseSense = 120f;
    [SerializeField] private float minAngle = -70f;
    [SerializeField] private float maxAngle = 80f;
    [SerializeField] private Transform cam;

    [Header("Movement")]
    [SerializeField] private float speed = 5f;
    [SerializeField] private float acceleration = 6f;

    [Header("Gun")]
    [SerializeField] private float bulletSpeed = 40f;
    [SerializeField] private float rateOfFire = 300f;
    [SerializeField] private float slideRecoil = 0.05f;
    [SerializeField] private float verticalRecoil = 3f;
    [SerializeField] private Vector3 defaultPosition;
    [SerializeField] private Transform gun;
    [SerializeField] private Transform bulletSpawn;
    [SerializeField] private Rigidbody bulletPrefab;
    [Header("Bullet Materials")]
    [SerializeField] private Material[] bulletMaterials;

    private bool canShoot = true;
    private float xrot;
    private float yrot;

    private Vector2 inputDir;
    private Rigidbody rigidBody;

    private Vector3 targetLocalPos;
    private Vector3 currentLocalPos;
    private Vector3 targetLocalEuler;
    private Vector3 currentLocalEuler;

    private void Start()
    {
        rigidBody = GetComponent<Rigidbody>();

        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;

        yrot = transform.eulerAngles.y;
        targetLocalPos = defaultPosition;
        currentLocalPos = gun.localPosition;

        targetLocalEuler = Vector3.zero;
        currentLocalEuler = gun.localEulerAngles;
    }
    private void Update()
    {
        float vertical = Input.GetAxisRaw("Vertical");
        float horizontal = Input.GetAxisRaw("Horizontal");
        inputDir = new Vector2(vertical, horizontal);

        float mouseX = Input.GetAxis("Mouse X");
        float mouseY = Input.GetAxis("Mouse Y");

        xrot -= mouseY * mouseSense * Time.deltaTime;
        yrot += mouseX * mouseSense * Time.deltaTime;

        xrot = Mathf.Clamp(xrot, minAngle, maxAngle);
        cam.localRotation = Quaternion.Euler(xrot, 0f, 0f);
        transform.rotation = Quaternion.Euler(0f, yrot, 0f);

        if (Input.GetKey(KeyCode.Mouse0) && canShoot) Fire();

        currentLocalPos = Vector3.Lerp(currentLocalPos, targetLocalPos, 12f * Time.deltaTime);
        currentLocalEuler = Vector3.Lerp(currentLocalEuler, targetLocalEuler, 12f * Time.deltaTime);

        gun.SetLocalPositionAndRotation(currentLocalPos, Quaternion.Euler(currentLocalEuler));
        targetLocalPos = Vector3.Lerp(targetLocalPos, defaultPosition, 5f * Time.deltaTime);
        targetLocalEuler = Vector3.Lerp(targetLocalEuler, Vector3.zero, 5f * Time.deltaTime);
    }

    private void FixedUpdate()
    {
        Vector3 input = transform.forward * inputDir.x + transform.right * inputDir.y;

        Vector3 desiredVel = input * speed;
        Vector3 velChange = desiredVel - rigidBody.linearVelocity;

        Vector3 force = rigidBody.mass * acceleration * velChange;
        rigidBody.AddForce(force, ForceMode.Force);
    }

    private void Fire()
    {
        Rigidbody b = Instantiate(bulletPrefab, bulletSpawn.position, bulletSpawn.rotation);
        b.linearVelocity = bulletSpawn.forward * bulletSpeed;

        targetLocalPos += Vector3.back * slideRecoil;
        targetLocalEuler += new Vector3(-verticalRecoil, 0f, 0f);

        StartCoroutine(DelayShot());
    }

    private IEnumerator DelayShot()
    {
        canShoot = false;
        float delay = 60f / rateOfFire;
        yield return new WaitForSeconds(delay);

        canShoot = true;
    }
}